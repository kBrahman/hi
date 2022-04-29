// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names
import 'dart:core';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/signal/signaling.dart';
import 'package:hi/util/util.dart';
import 'package:package_info/package_info.dart';
import 'package:wakelock/wakelock.dart';

class Call extends StatefulWidget {
  final String ip;
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
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool micMuted = false;

  bool _connOk = true;
  bool _maintaining = false;
  var countToShowAd = 1;
  var nextCount = 0;
  var inCall = false;

  late MethodChannel platform;
  String? model;
  bool blockDialogShown = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _signaling.isDisconnected() ? checkAndConnect() : _signaling.msgNew();
        hiLog(TAG, "app in resumed");
        break;
      case AppLifecycleState.inactive:
        hiLog(TAG, "app in inactive");
        break;
      case AppLifecycleState.paused:
        _signaling.bye(true);
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
        setState(() {
          inCall = false;
        });
        hiLog(TAG, "app in paused");
        break;
      case AppLifecycleState.detached:
        _signaling.close();
        _signaling.disconnect();
        hiLog(TAG, "app in detached");
        break;
    }
  }

  @override
  initState() {
    super.initState();
    initRenderers();
    initSignalingServer();
    if (Platform.isAndroid) platform = const MethodChannel('hi.channel/app');
    hiLog(TAG, 'init state');
  }

  void initSignalingServer() async {
    final version = (await PackageInfo.fromPlatform()).version;
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final model = Platform.isAndroid ? (await deviceInfo.androidInfo).model : (await deviceInfo.iosInfo).model;
    final height = WidgetsBinding.instance?.window.physicalSize.height;
    final width = WidgetsBinding.instance?.window.physicalSize.width;
    _signaling = Signaling(widget.ip, widget.turnServer, widget.turnUname, widget.turnPass, '$height:$width', model, version);
    _signaling.onStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.CallStateBye:
          if (!blockDialogShown) next(inCall);
          setState(() => inCall = false);
          break;
        case SignalingState.ConnectionClosed:
          break;
        case SignalingState.ConnectionError:
          setState(() {
            _maintaining = true;
          });
          break;
        case SignalingState.NoInet:
          setState(() {
            _connOk = false;
          });
          break;
        case SignalingState.ConnectionOpen:
          Wakelock.enable();
          break;
      }
    };

    _signaling.onStreams = ((rStream, lStream) {
      setState(() {
        _remoteRenderer.srcObject = rStream;
        _localRenderer.srcObject = lStream;
        inCall = true;
      });
      hiLog(TAG, 'onRemoteStream');
    });

    _signaling.onRemoveRemoteStream = (() {
      _remoteRenderer.srcObject = null;
      hiLog(TAG, 'onRemoveRemoteStream');
    });
    checkAndConnect();
    WidgetsBinding.instance?.addObserver(this);
  }

  showSnack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: inCall
          ? null
          : AppBar(
              title: const Text('hi'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: inCall
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                  5,
                  (i) => ElevatedButton(
                      child: icon(i),
                      style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(15)),
                      onPressed: onPressed(i, context))))
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
              ? const WaitingWidget()
              : !_connOk
                  ? NoInternetWidget(checkAndConnect)
                  : const MaintenanceWidget(),
    );
  }

  Icon? icon(int i) => Icon(i == 0
      ? Icons.switch_camera
      : i == 1
          ? Icons.call_end
          : i == 2
              ? (micMuted ? Icons.mic_off : Icons.mic)
              : i == 3
                  ? Icons.skip_next
                  : Icons.block);

  VoidCallback? onPressed(int i, BuildContext context) {
    switch (i) {
      case 0:
        return _signaling.switchCamera;
      case 1:
        return _hangUp;
      case 2:
        return _muteMic;
      case 3:
        return () {
          setState(() {
            inCall = false;
          });
          _signaling.bye(true);
          next(true);
        };
      case 4:
        return () => block(context);
      default:
        return null;
    }
  }

  block(BuildContext context) async {
    blockDialogShown = true;
    var res = await showDialog(
        context: context,
        builder: (_) => AlertDialog(
                content: Text(AppLocalizations.of(context)?.block_report ?? 'You can block or report a complaint on this user'),
                actions: [
                  TextButton(onPressed: Navigator.of(context).pop, child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'complaint'),
                      child: Text(AppLocalizations.of(context)?.complaint ?? 'Complaint')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'block'),
                      child: Text(AppLocalizations.of(context)?.block ?? 'BLOCK'))
                ]));
    switch (res) {
      case 'block':
        hiLog(TAG, 'result is block');
        showSnack(AppLocalizations.of(context)?.blocked ?? 'User is blocked');
        Future.delayed(const Duration(milliseconds: 250), () {
          if (inCall) _signaling.bye(true);
          next(false);
          setState(() => inCall = false);
        });
        break;
      case 'complaint':
        hiLog(TAG, 'result is complaint');
        showSnack(AppLocalizations.of(context)?.report_sent ?? 'Complaint sent');
        sendReport();
        if (!inCall) next(false);
        break;
      case null:
        hiLog(TAG, 'result is null');
        if (!inCall) next(false);
    }
    blockDialogShown = false;
  }

  next(bool canShowAd) async {
    hiLog(TAG, 'nextCount=>$nextCount, countToShowAd=>$countToShowAd');
    if (canShowAd && Platform.isAndroid && ++nextCount == countToShowAd && await platform.invokeMethod('isLoaded')) {
      platform.invokeMethod('show');
      nextCount = 0;
      countToShowAd *= 2;
      return;
    }
    hiLog(TAG, 'on next');
    _remoteRenderer.srcObject = null;
    _signaling.close();
    _signaling.msgNew();
  }

  initRenderers() async {
    _localRenderer.initialize();
    _remoteRenderer.initialize();
  }

  _hangUp() async {
    _signaling.bye(true);
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
    setState(() {
      _connOk = connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi;
    });
    if (_connOk) _signaling.connect();
  }

  void sendReport() {}
}

class MaintenanceWidget extends StatelessWidget {
  const MaintenanceWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          child: Text(
            AppLocalizations.of(context)?.maintenance ?? 'Maintenance works on server side, come later please',
          ),
          padding: const EdgeInsets.only(left: 20, right: 10),
        ),
      );
}

class NoInternetWidget extends StatelessWidget {
  final VoidCallback checkConn;

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

class WaitingWidget extends StatelessWidget {
  static const TAG = 'Hi_WaitingWidgetState';

  const WaitingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const String viewType = 'medium_rectangle';
    final Map<String, dynamic> creationParams = <String, dynamic>{};
    return Center(
      child: Column(
        children: <Widget>[
          if (Platform.isAndroid)
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
