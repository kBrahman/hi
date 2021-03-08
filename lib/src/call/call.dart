import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:admob_flutter/admob_flutter.dart';
import 'package:data_connection_checker/data_connection_checker.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/l10n/locale.dart';
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
  var colorCodes = {
    50: Color.fromRGBO(211, 10, 75, .1),
    for (var i = 100; i < 1000; i += 100) i: Color.fromRGBO(247, 0, 15, (i + 100) / 1000)
  };

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
      adUnitId: Platform.isIOS
          ? AdmobInterstitial.testAdUnitId
          : 'ca-app-pub-8761730220693010/2067844692',
      listener: (AdmobAdEvent event, Map<String, dynamic> args) {
        if (event == AdmobAdEvent.closed) {
          _signaling.msgNew(ww.model);
          interstitialAd.load();
        }
      },
    )..load();
    //int id ca-app-pub-8761730220693010/2067844692
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate
        ],
        supportedLocales: LOCALES,
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
                          child: micMuted ? const Icon(Icons.mic_off) : const Icon(Icons.mic),
                          onPressed: _muteMic,
                        ),
                        FloatingActionButton(
                          child: const Icon(Icons.skip_next),
                          onPressed: () => _signaling.bye(++nextPressCount == adTrigger),
                        )
                      ]))
              : null,
          body: _inCalling
              ? OrientationBuilder(builder: (context, orientation) {
                  return Container(
                    child: Stack(children: <Widget>[
                      Container(
                        margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: RTCVideoView(_remoteRenderer),
                        decoration: BoxDecoration(color: colorCodes[400]),
                      ),
                      Positioned(
                        left: 20.0,
                        top: 10.0,
                        child: ClipOval(
                          child: Container(
                            width: 100.0,
                            height: 100.0,
                            child: RTCVideoView(_localRenderer),
                            decoration: BoxDecoration(color: Colors.black54),
                          ),
                        ),
                      ),
                    ]),
                  );
                })
              : _connOk && !_maintaining
                  ? ww
                  : !_connOk
                      ? NoInternetWidget(checkConn)
                      : MaintenanceWidget(),
        ),
      );

  onNext() {
    if (nextPressCount == adTrigger) {
      nextPressCount = 0;
      adTrigger *= 2;
      interstitialAd.isLoaded.then((isLoaded) {
        if (isLoaded) {
          interstitialAd.show();
        } else {
          _signaling.msgNew(ww.model);
        }
      });
    } else {
      _signaling.msgNew(ww.model);
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
            onNext();
            break;
          case SignalingState.CallStateInvite:
          case SignalingState.CallStateConnected:
          case SignalingState.CallStateRinging:
          case SignalingState.ConnectionClosed:
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

class MaintenanceWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          child: Text(
            AppLocalizations.of(context).maintenance,
          ),
          padding: EdgeInsets.only(left: 20, right: 10),
        ),
      );
}

class NoInternetWidget extends StatelessWidget {
  final checkConn;

  NoInternetWidget(this.checkConn);

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          children: <Widget>[
            Text(AppLocalizations.of(context).no_inet),
            RaisedButton(
              onPressed: checkConn,
              child: Text(AppLocalizations.of(context).refresh),
            )
          ],
          mainAxisAlignment: MainAxisAlignment.center,
        ),
      );
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
              switch (event) {
                case AdmobAdEvent.opened:
                  widget.signaling.bye(true);
                  break;
                case AdmobAdEvent.closed:
                  widget.signaling.msgNew(widget.model);
              }
            },
          ),
          Padding(padding: EdgeInsets.only(top: 5)),
          CircularProgressIndicator(),
          Padding(padding: EdgeInsets.only(top: 10)),
          Text(AppLocalizations.of(context).waiting),
        ],
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );
  }
}
