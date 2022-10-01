// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names
import 'dart:core';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/util/signaling.dart';
import 'package:hi/util/util.dart';
import 'package:package_info/package_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wakelock/wakelock.dart';

class CallWidget extends StatefulWidget {
  final String ip;
  final Iterable<String> turnServers;
  final String turnUname;
  final String turnPass;
  final VoidCallback _onBack;
  final Function(String, DateTime, int) _block;
  final Database _db;
  final String _name;

  const CallWidget(this._onBack, this._block, this._db, this._name,
      {Key? key, required this.ip, required this.turnServers, required this.turnUname, required this.turnPass})
      : super(key: key);

  @override
  _CallWidgetState createState() => _CallWidgetState();
}

class _CallWidgetState extends State<CallWidget> with WidgetsBindingObserver {
  static const TAG = 'Hi_CallState';
  Signaling? _signaling;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool micMuted = false;

  bool _connOk = true;
  bool _maintaining = false;
  var _countToShowAd = 1;
  var _nextCount = 0;
  var _inCall = false;
  late String _login;
  late MethodChannel _platform;
  String? model;
  bool blockDialogShown = false;
  late int _lastBlockPeriod;
  bool _mustUpdate = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_inCall && _signaling?.isConnecting() == false)
          _signaling?.isDisconnected() ? checkAndConnect() : _signaling?.msgNew();
        hiLog(TAG, "app in resumed");
        break;
      case AppLifecycleState.paused:
        _signaling?.close();
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
        setState(() => _inCall = false);
        hiLog(TAG, 'paused');
        break;
      case AppLifecycleState.inactive:
        hiLog(TAG, 'inactive');
    }
  }

  @override
  initState() {
    super.initState();
    initRenderers();
    if (Platform.isAndroid) _platform = const MethodChannel('hi.channel/app');
    _checkBlock(widget._name);
  }

  _checkBlock(String name) async {
    hiLog(TAG, 'is blocked');
    final sharedPrefs = await SharedPreferences.getInstance();
    _login = sharedPrefs.getString(LOGIN) ?? '';
    final DocumentSnapshot doc;
    if (_login.isNotEmpty &&
        (doc = await FirebaseFirestore.instance.doc('user/$_login').get()).exists &&
        doc[BLOCK_PERIOD] != BLOCK_NO) {
      final periodCode = doc[BLOCK_PERIOD];
      final blockTime = doc[BLOCK_TIME];
      sharedPrefs.setInt(BLOCK_PERIOD, periodCode);
      sharedPrefs.setInt(BLOCK_TIME, (blockTime as Timestamp).millisecondsSinceEpoch);
      widget._db.update(
          TABLE_USER, {BLOCK_PERIOD: periodCode, LAST_BLOCK_PERIOD: periodCode, BLOCK_TIME: blockTime.millisecondsSinceEpoch},
          where: 'login=?', whereArgs: [_login]);
      widget._block(_login, blockTime.toDate().add(Duration(minutes: getMinutes(periodCode))), periodCode);
    } else
      _initSignalingServer(_login, name);
  }

  void _initSignalingServer(String login, String name) async {
    final version = (await PackageInfo.fromPlatform()).version;
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final model = Platform.isAndroid ? (await deviceInfo.androidInfo).model : (await deviceInfo.iosInfo).model;
    final height = WidgetsBinding.instance.window.physicalSize.height;
    final width = WidgetsBinding.instance.window.physicalSize.width;
    _signaling = Signaling(login, name, widget.ip, widget.turnServers, widget.turnUname, widget.turnPass, '$height:$width', model,
        version, widget._db);
    _signaling?.onStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.CallStateBye:
          if (!mounted) return;
          if (!blockDialogShown) _next(_inCall);
          setState(() => _inCall = false);
          break;
        case SignalingState.ConnectionClosed:
          break;
        case SignalingState.ConnectionError:
          setState(() => _maintaining = true);
          break;
        case SignalingState.NoInet:
          setState(() => _connOk = false);
          break;
        case SignalingState.ConnectionOpen:
          Wakelock.enable();
          break;
        case SignalingState.Block:
          final now = DateTime.now();
          final blockPeriodCode = getBlockPeriod(_lastBlockPeriod);
          widget._db.update(TABLE_USER,
              {BLOCK_PERIOD: blockPeriodCode, BLOCK_TIME: now.millisecondsSinceEpoch, LAST_BLOCK_PERIOD: blockPeriodCode},
              where: '$LOGIN=?', whereArgs: [_login]);
          FirebaseFirestore.instance
              .doc('user/$_login')
              .set({BLOCK_PERIOD: blockPeriodCode, BLOCK_TIME: Timestamp.now(), LAST_BLOCK_PERIOD: blockPeriodCode});
          widget._block(_login, now.add(Duration(minutes: getMinutes(blockPeriodCode))), blockPeriodCode);
          break;
        case SignalingState.Update:
          setState(() {
            _mustUpdate = true;
          });
      }
    };

    _signaling?.onStreams = ((rStream, lStream) {
      setState(() {
        _remoteRenderer.srcObject = rStream;
        _localRenderer.srcObject = lStream;
        _inCall = true;
      });
    });

    _signaling?.onRemoveRemoteStream = (() {
      _remoteRenderer.srcObject = null;
    });
    checkAndConnect();
    WidgetsBinding.instance.addObserver(this);
  }

  int getBlockPeriod(int lastBlockedPeriod) => lastBlockedPeriod < BLOCK_YEAR ? lastBlockedPeriod + 1 : BLOCK_YEAR;

  @override
  Widget build(BuildContext context) => WillPopScope(
      child: Scaffold(
          appBar: _inCall ? null : AppBar(title: nameWidget, leading: BackButton(onPressed: widget._onBack)),
          floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
          floatingActionButton: _inCall
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                      4,
                      (i) => ElevatedButton(
                          style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(15)),
                          onPressed: onPressed(i, context),
                          child: icon(i))))
              : null,
          body: _mustUpdate
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(AppLocalizations.of(context)?.must_update ?? 'You must update you app',
                      style: const TextStyle(fontSize: 20)),
                  ElevatedButton(onPressed: _update, child: Text(AppLocalizations.of(context)?.update ?? 'UPDATE'))
                ]))
              : _inCall
                  ? OrientationBuilder(builder: (context, orientation) {
                      return Stack(children: <Widget>[
                        RTCVideoView(_remoteRenderer),
                        Positioned(left: 20.0, top: 10.0, width: 90, height: 120, child: RTCVideoView(_localRenderer))
                      ]);
                    })
                  : _connOk && !_maintaining
                      ? const WaitingWidget()
                      : !_connOk
                          ? NoInternetWidget(checkAndConnect)
                          : const MaintenanceWidget()),
      onWillPop: () {
        widget._onBack();
        return Future.value(false);
      });

  @override
  void dispose() {
    // platform.invokeMethod('isLoaded').then((value) => {if (value) platform.invokeMethod('show')});
    WidgetsBinding.instance.removeObserver(this);
    _signaling?.close();
    _signaling = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    hiLog(TAG, 'dispose');
    super.dispose();
  }

  Icon? icon(int i) => Icon(i == 0
      ? Icons.call_end
      : i == 1
          ? (micMuted ? Icons.mic_off : Icons.mic)
          : i == 2
              ? Icons.skip_next
              : Icons.block);

  VoidCallback? onPressed(int i, BuildContext context) {
    switch (i) {
      case 0:
        return widget._onBack;
      case 1:
        return _muteMic;
      case 2:
        return () {
          setState(() {
            _inCall = false;
          });
          _next(true);
        };
      case 3:
        return () => _block(context);
      default:
        return null;
    }
  }

  _block(BuildContext context) async {
    blockDialogShown = true;
    var res = await showDialog(
        context: context,
        builder: (_) => AlertDialog(
                content: Text(AppLocalizations.of(context)?.block_report ?? 'You can block or report a complaint on this user'),
                actions: [
                  TextButton(onPressed: Navigator.of(context).pop, child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, REPORT),
                      child: Text(AppLocalizations.of(context)?.complaint ?? 'Complaint')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, BLOCK), child: Text(AppLocalizations.of(context)?.block ?? 'BLOCK'))
                ]));
    switch (res) {
      case BLOCK:
        _signaling?.block();
        showSnack(AppLocalizations.of(context)?.blocked ?? 'User is blocked', 4, context);
        Future.delayed(const Duration(milliseconds: 250), () {
          _next(false);
          setState(() => _inCall = false);
        });
        break;
      case REPORT:
        showSnack(AppLocalizations.of(context)?.report_sent ?? 'Complaint sent', 4, context);
        _signaling?.report();
        if (!_inCall) _next(false);
        break;
      case null:
        if (!_inCall) _next(false);
    }
    blockDialogShown = false;
  }

  _next(bool canShowAd) async {
    hiLog(TAG, 'nextCount=>$_nextCount, countToShowAd=>$_countToShowAd');
    if (canShowAd && ++_nextCount == _countToShowAd && await _platform.invokeMethod('isLoaded')) {
      _platform.invokeMethod('show').then((_) {
        _nextCount = 0;
        _countToShowAd *= 2;
      }).catchError((e) => _signaling?.connect());
      _signaling?.close();
      _remoteRenderer.srcObject = null;
      _localRenderer.srcObject = null;
    } else
      closeAndConnect();
  }

  void closeAndConnect() {
    _signaling?.close();
    _signaling?.connect();
    _remoteRenderer.srcObject = null;
    _localRenderer.srcObject = null;
  }

  initRenderers() async {
    _localRenderer.initialize();
    _remoteRenderer.initialize();
  }

  _muteMic() {
    setState(() {
      micMuted = !micMuted;
    });
    _signaling?.mute(micMuted);
  }

  checkAndConnect() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    setState(() {
      _connOk = connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi;
    });
    if (_connOk) _signaling?.connect();
  }

  void _update() => _platform.invokeMethod(UPDATE).then((value) {
        if (!value)
          showSnack(AppLocalizations.of(context)?.gp ?? 'Could not open Google Play.Open it manually please', 5, context);
      });
}

class MaintenanceWidget extends StatelessWidget {
  const MaintenanceWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Center(
      child: Container(
          child: Text(
            AppLocalizations.of(context)?.maintenance ?? 'Maintenance works on server side, come later please',
          ),
          padding: const EdgeInsets.only(left: 20, right: 10)));
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
