import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:wakelock/wakelock.dart';

import 'signaling.dart';

class Call extends StatefulWidget {
  final String ip;

  Call({Key key, @required this.ip}) : super(key: key);

  @override
  _CallState createState() => new _CallState(serverIP: ip);
}

class _CallState extends State<Call> {
  Signaling _signaling;
  String _displayName =
      Platform.localHostname + '(' + Platform.operatingSystem + ")";
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();
  bool _inCalling = false;
  bool micMuted = false;

  final String serverIP;
  bool _connOk = true;
  bool _maintaining = false;

  _CallState({Key key, @required this.serverIP}) {
    checkConn();
  }

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    if (_signaling != null) _signaling.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _connect() async {
    if (_signaling == null) {
      _signaling = new Signaling(serverIP, _displayName)..connect();

      _signaling.onStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.CallStateNew:
            this.setState(() {
              _inCalling = true;
            });
            break;
          case SignalingState.CallStateBye:
            this.setState(() {
              _localRenderer.srcObject = null;
              _remoteRenderer.srcObject = null;
              _inCalling = false;
            });
            _signaling.msgNew();
            break;
          case SignalingState.CallStateInvite:
          case SignalingState.CallStateConnected:
          case SignalingState.CallStateRinging:
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
            setState(() {
              print("conn err");
              _maintaining = true;
            });
            break;
          case SignalingState.ConnectionOpen:
            Wakelock.enable();
            break;
        }
      };

      _signaling.onLocalStream = ((stream) {
        _localRenderer.srcObject = stream;
      });

      _signaling.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
      });

      _signaling.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }

  _hangUp() {
    if (_signaling != null) {
      _signaling.close();
      exit(0);
    }
  }

  _switchCamera() {
    _signaling.switchCamera();
  }

  _muteMic() {
    setState(() {
      micMuted = !micMuted;
    });
    _signaling.mute(micMuted);
  }

  Future<void> checkConn() async {
    var b = await DataConnectionChecker().hasConnection;
    setState(() {
      _connOk = b;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('hi'),
          backgroundColor: Color(0xFFE10A50),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _inCalling
            ? new SizedBox(
                width: 250.0,
                child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      FloatingActionButton(
                        child: const Icon(Icons.switch_camera),
                        onPressed: _switchCamera,
                      ),
                      FloatingActionButton(
                        onPressed: _hangUp,
                        tooltip: 'Hangup',
                        child: new Icon(Icons.call_end),
                        backgroundColor: Colors.pink,
                      ),
                      FloatingActionButton(
                        child: micMuted
                            ? const Icon(Icons.mic_off)
                            : const Icon(Icons.mic),
                        onPressed: _muteMic,
                      ),
                      FloatingActionButton(
                        child: const Icon(Icons.skip_next),
                        onPressed: _signaling.bye,
                      )
                    ]))
            : null,
        body: _inCalling
            ? OrientationBuilder(builder: (context, orientation) {
                return Container(
                  child: Stack(children: <Widget>[
                    Positioned(
                        left: 0.0,
                        right: 0.0,
                        top: 0.0,
                        bottom: 0.0,
                        child: new Container(
                          margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: new RTCVideoView(_remoteRenderer),
                          decoration: new BoxDecoration(color: Colors.black54),
                        )),
                    Positioned(
                      left: 20.0,
                      top: 20.0,
                      child: new Container(
                        width:
                            orientation == Orientation.portrait ? 90.0 : 120.0,
                        height:
                            orientation == Orientation.portrait ? 120.0 : 90.0,
                        child: RTCVideoView(_localRenderer),
                        decoration: BoxDecoration(color: Colors.black54),
                      ),
                    ),
                  ]),
                );
              })
            : _connOk && !_maintaining
                ? WaitingWidget()
                : !_connOk
                    ? Center(
                        child: Column(
                          children: <Widget>[
                            Text("No internet access"),
                            RaisedButton(
                              onPressed: checkConn,
                              child: Text("Refresh"),
                            )
                          ],
                          mainAxisAlignment: MainAxisAlignment.center,
                        ),
                      )
                    : Center(
                        child: Container(
                          child: Text(
                            "Maintenance works on server side come later please",
                          ),
                          padding: EdgeInsets.only(left: 20, right: 10),
                        ),
                      ),
      ),
    );
  }
}

class WaitingWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new Column(
        children: <Widget>[
          CircularProgressIndicator(),
          Padding(padding: EdgeInsets.only(top: 10)),
          Text("Waiting for someone..."),
        ],
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );
  }
}
