// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names

import 'dart:core';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/l10n/locale.dart';
import 'package:hi/signal/signaling.dart';
import 'package:hi/util/util.dart';
import 'package:package_info/package_info.dart';
import 'package:wakelock/wakelock.dart';

class Call extends StatefulWidget {
  final String? ip;
  final String turnServer;
  final String turnUname;
  final String turnPass;

  const Call({Key? key, required this.ip, required this.turnServer, required this.turnUname, required this.turnPass})
      : super(key: key);

  @override
  _CallState createState() => _CallState();
}

class _CallState extends State<Call> with WidgetsBindingObserver {
  static const TAG = 'Hi_CallState';
  late Signaling _signaling;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool micMuted = false;

  bool _connOk = true;
  bool _maintaining = false;
  final waitingWidget = WaitingWidget();
  var countToShowAd = 1;
  var nextCount = 0;
  var colorCodes = {
    50: const Color.fromRGBO(211, 10, 75, .1),
    for (var i = 100; i < 1000; i += 100) i: Color.fromRGBO(247, 0, 15, (i + 100) / 1000)
  };

  // InterstitialAd? interstitial;
  double? _h;
  double? _w;
  String? version;

  var inCall = false;
  var connecting = false;
  late MethodChannel platform;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!connecting) _signaling.isClosed() ? checkAndConnect() : _signaling.msgNew(waitingWidget.model, '$_h:$_w', version);
        hiLog(TAG, "app in resumed");
        break;
      case AppLifecycleState.inactive:
        hiLog(TAG, "app in inactive");
        break;
      case AppLifecycleState.paused:
        _signaling.bye(true);
        _signaling.close();
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
        hiLog(TAG, "app in paused");
        break;
      case AppLifecycleState.detached:
        hiLog(TAG, "app in detached");
        break;
    }
  }

  @override
  initState() {
    super.initState();
    PackageInfo.fromPlatform().then((value) => version = value.version);
    _signaling = Signaling(widget.ip, widget.turnServer, widget.turnUname, widget.turnPass);
    _h = WidgetsBinding.instance?.window.physicalSize.height;
    _w = WidgetsBinding.instance?.window.physicalSize.width;
    initRenderers();
    checkAndConnect();
    platform = const MethodChannel('hi.channel/app');
    hiLog(TAG, 'init state');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate
      ],
      supportedLocales: LOCALES,
      localeResolutionCallback: (locale, supportedLocales) => supportedLocales
          .firstWhere((element) => element.languageCode == locale?.languageCode, orElse: () => supportedLocales.first),
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFFE10A50, colorCodes),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: inCall
            ? null
            : AppBar(
                title: const Text('hi'),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: inCall
            ? SizedBox(
                width: 250.0,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                  FloatingActionButton(
                    child: const Icon(Icons.switch_camera),
                    onPressed: () {
                      _signaling.switchCamera();
                    },
                  ),
                  FloatingActionButton(
                    onPressed: _hangUp,
                    tooltip: 'Hangup',
                    child: const Icon(Icons.call_end),
                  ),
                  FloatingActionButton(
                    child: micMuted ? const Icon(Icons.mic_off) : const Icon(Icons.mic),
                    onPressed: _muteMic,
                  ),
                  FloatingActionButton(
                      child: const Icon(Icons.skip_next),
                      onPressed: () {
                        _signaling.bye(true);
                        next();
                        setState(() => inCall = false);
                      })
                ]))
            : null,
        body: inCall
            ? OrientationBuilder(builder: (context, orientation) {
                return Stack(children: <Widget>[
                  RTCVideoView(_remoteRenderer),
                  Positioned(
                    left: 20.0,
                    top: 10.0,
                    width: 90,
                    height: 120,
                    child: RTCVideoView(_localRenderer),
                  ),
                ]);
              })
            : _connOk && !_maintaining
                ? waitingWidget
                : !_connOk
                    ? NoInternetWidget(checkAndConnect)
                    : const MaintenanceWidget(),
      ),
    );
  }

  next() async {
    hiLog(TAG, 'nextCount=>$nextCount, countToShowAd=>$countToShowAd');
    if (++nextCount == countToShowAd && await platform.invokeMethod('isLoaded')) {
      platform.invokeMethod('show');
      nextCount = 0;
      countToShowAd *= 2;
      return;
    }
    hiLog(TAG, 'on next');
    _remoteRenderer.srcObject = null;
    _signaling.msgNew(waitingWidget.model, '$_h:$_w', version);
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    _signaling.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.deactivate();
  }

  void _connect(String? model, String localMC) async {
    connecting = true;
    _signaling.connect(model, localMC, version);
    _signaling.onStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.CallStateBye:
          next();
          setState(() => inCall = false);
          break;
        case SignalingState.ConnectionClosed:
          break;
        case SignalingState.ConnectionError:
          setState(() {
            _maintaining = true;
          });
          break;
        case SignalingState.ConnectionOpen:
          connecting = false;
          Wakelock.enable();
          break;
      }
    };

    _signaling.onLocalStream = ((stream) {
      _localRenderer.srcObject = stream;
      hiLog(TAG, 'onLocalStream');
    });

    _signaling.onRemoteStream = ((stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        inCall = true;
      });
      hiLog(TAG, 'onRemoteStream');
    });

    _signaling.onRemoveRemoteStream = ((stream) {
      _remoteRenderer.srcObject = null;
      hiLog(TAG, 'onRemoveRemoteStream');
    });
  }

  _hangUp() async {
    if (Platform.isAndroid)
      SystemNavigator.pop();
    else
      exit(0);
  }

  _muteMic() {
    setState(() {
      micMuted = !micMuted;
    });
    _signaling.mute(micMuted);
  }

  checkAndConnect() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    setState(() {
      _connOk = connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi;
    });
    if (Platform.isAndroid && _connOk)
      deviceInfo.androidInfo.then((v) {
        _connect(v.model, '$_h:$_w');
        waitingWidget.signaling = _signaling;
        waitingWidget.model = v.model;
        waitingWidget.h = _h;
        waitingWidget.w = _w;
        WidgetsBinding.instance?.addObserver(this);
      });
    else if (_connOk)
      deviceInfo.iosInfo.then((v) {
        _connect(v.model, '$_h:$_w');
        waitingWidget.signaling = _signaling;
        waitingWidget.model = v.model;
        WidgetsBinding.instance?.addObserver(this);
      });
  }
}

class MaintenanceWidget extends StatelessWidget {
  const MaintenanceWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          child: Text(
            AppLocalizations.of(context)?.maintenance ?? 'Maintenance works on server side, come later please',
          ),
          padding: EdgeInsets.only(left: 20, right: 10),
        ),
      );
}

class NoInternetWidget extends StatelessWidget {
  final checkConn;

  const NoInternetWidget(this.checkConn, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Center(
          child: Column(children: <Widget>[
        Text(AppLocalizations.of(context)?.no_inet ?? 'No internet'),
        ElevatedButton(
          onPressed: checkConn,
          child: Text(AppLocalizations.of(context)?.refresh ?? 'Refresh'),
        )
      ], mainAxisAlignment: MainAxisAlignment.center));
}

class WaitingWidget extends StatefulWidget {
  Signaling? signaling;

  String? model;
  double? h;
  double? w;

  @override
  State<StatefulWidget> createState() => _WaitingWidgetState();
}

class _WaitingWidgetState extends State<WaitingWidget> {
  static const TAG = 'Hi_WaitingWidgetState';

  @override
  Widget build(BuildContext context) {
    const String viewType = 'medium_rectangle';
    final Map<String, dynamic> creationParams = <String, dynamic>{};
    return Center(
      child: Column(
        children: <Widget>[
          SizedBox(
              child: AndroidView(
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
              ),
              height: 250),
          const Padding(padding: EdgeInsets.only(top: 5)),
          const CircularProgressIndicator(),
          const Padding(padding: EdgeInsets.only(top: 10)),
          Text(AppLocalizations.of(context)?.waiting ?? 'Waiting for someone'),
        ],
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );
  }
}
