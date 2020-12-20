import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:admob_flutter/admob_flutter.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock/wakelock.dart';

import 'signaling.dart';

var colorCodes = {
  50: Color.fromRGBO(211, 10, 75, .1),
  for (var i = 100; i < 1000; i += 100)
    i: Color.fromRGBO(247, 0, 15, (i + 100) / 1000)
};

class Call extends StatefulWidget {
  final String ip;

  Call({Key key, @required this.ip}) : super(key: key);

  @override
  _CallState createState() => new _CallState(serverIP: ip);
}

class _CallState extends State<Call> {
  Signaling _signaling;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();
  bool _inCalling = false;
  bool micMuted = false;

  final String serverIP;
  bool _connOk = true;
  bool _maintaining = false;

  final ww = WaitingWidget();

  var interstitialAd;
  var adTrigger = 1;
  var nextPressCount = 0;
  var shouldCallNext = true;

  _CallState({@required this.serverIP}) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      deviceInfo.androidInfo.then((v) {
        _connect(v.model);
        ww.signaling = _signaling;
        ww.model = v.model;
      });
    } else {
      deviceInfo.iosInfo.then((v) {
        _connect(v.model);
        ww.signaling = _signaling;
        ww.model = v.model;
      });
    }
    checkConn();
    interstitialAd = AdmobInterstitial(
      adUnitId: 'ca-app-pub-8761730220693010/2067844692',
      listener: (AdmobAdEvent event, Map<String, dynamic> args) {
        print('int event=>$event');
        if (event == AdmobAdEvent.closed) {
          _signaling.msgNew(ww.model);
          _signaling.busy(false);
          interstitialAd.load();
        }
      },
    )..load();
    //int id ca-app-pub-8761730220693010/2067844692
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', ''), // English, no country code
        const Locale('hi', ''), // Hebrew, no country code
      ],
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFFE10A50, colorCodes),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: new Scaffold(
        appBar: AppBar(
          title: Text('hi'),
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
                      ),
                      FloatingActionButton(
                        child: micMuted
                            ? const Icon(Icons.mic_off)
                            : const Icon(Icons.mic),
                        onPressed: _muteMic,
                      ),
                      FloatingActionButton(
                        child: const Icon(Icons.skip_next),
                        onPressed: onNext,
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
                ? ww
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

  onNext() {
    nextPressCount++;
    if (nextPressCount == adTrigger) {
      nextPressCount = 0;
      adTrigger *= 2;
      interstitialAd.isLoaded.then((isLoaded) {
        if (isLoaded) {
          interstitialAd.show();
          shouldCallNext = false;
          _signaling.bye();
          _signaling.busy(true);
          setState(() {
            _inCalling = false;
          });
        } else {
          print("not loaded");
          shouldCallNext = true;
          _signaling.bye();
        }
      });
    } else {
      print('on next top else');
      shouldCallNext = true;
      _signaling.bye();
    }
  }

  @override
  initState() {
    super.initState();
    initRenderers();
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

  void _connect(String model) async {
    if (_signaling == null) {
      _signaling = new Signaling(serverIP)..connect(model);

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
            if (shouldCallNext) _signaling.msgNew(model);
            break;
          case SignalingState.CallStateInvite:
          case SignalingState.CallStateConnected:
          case SignalingState.CallStateRinging:
          case SignalingState.ConnectionClosed:
            print('on closed');
            break;
          case SignalingState.ConnectionError:
            setState(() {
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
}

class WaitingWidget extends StatefulWidget {
  Signaling signaling;

  String model;

  @override
  State<StatefulWidget> createState() => _WaitingWidgetState();
}

class _WaitingWidgetState extends State<WaitingWidget> {
  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new Column(
        children: <Widget>[
          AdmobBanner(
            adUnitId: Platform.isIOS
                ? AdmobBanner.testAdUnitId
                : "ca-app-pub-8761730220693010/9359738284",
            adSize: AdmobBannerSize.MEDIUM_RECTANGLE,
            listener: (AdmobAdEvent event, Map<String, dynamic> args) {
              print(
                  'Banner=>$event; bool=>${event == AdmobAdEvent.opened}; args=>$args');
              switch (event) {
                case AdmobAdEvent.opened:
                  print('signaling null=>${widget.signaling == null}');
                  widget.signaling.busy(true);
                  break;

                case AdmobAdEvent.closed:
                  widget.signaling.msgNew(widget.model);
                  widget.signaling.busy(false);
              }
            },
          ),
          Padding(padding: EdgeInsets.only(top: 5)),
          CircularProgressIndicator(),
          Padding(padding: EdgeInsets.only(top: 10)),
          Text("Waiting for someone..."),
        ],
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );
  }
}
