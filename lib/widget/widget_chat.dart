// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/util/util.dart';

import '../bloc/bloc_chat.dart';

//
//       {Key? key, required this.ip, required this.turnServers, required this.turnUname, required this.turnPass})
//       : super(key: key);
//
//   @override
//   _ChatWidgetState createState() => _ChatWidgetState();

class ChatWidget extends StatelessWidget {
  static const _TAG = 'ChatWidget';

  final ChatBloc _chatBloc;

  const ChatWidget(this._chatBloc, {Key? key}) : super(key: key);

  //   _start(widget._name);
  // }

  // _start(String name) async {
  //   if (!(await _isBlocked()) && mounted) _initSignaling(_login, name);
  // }

  // int getBlockPeriod(int lastBlockedPeriod) => lastBlockedPeriod < BLOCK_YEAR ? lastBlockedPeriod + 1 : BLOCK_YEAR;

  @override
  Widget build(BuildContext context) => StreamBuilder<ChatData>(
      initialData: const ChatData(),
      stream: _chatBloc.stream,
      builder: (context, snap) {
        if (snap.data?.blocked == true) WidgetsBinding.instance.addPostFrameCallback((_) => _blockUser(context));
        final state = snap.data!.state;
        final inCall = state == ChatState.IN_CALL;
        return Scaffold(
            appBar: AppBar(title: const Text('hi'), toolbarHeight: inCall ? 0 : null),
            floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
            floatingActionButton: inCall
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        4,
                        (i) => ElevatedButton(
                            style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(15)),
                            onPressed: onPressed(i, context),
                            child: icon(i, snap.data!.muted))))
                : null,
            body: _getBody(state, context));

        //             ? const WaitingWidget()
        //             : !_connOk
        //                 ? NoInternetWidget(checkAndConnect)
        //                 : const MaintenanceWidget());
      });

  // @override
  // void dispose() {
  //   platform.invokeMethod('isLoaded').then((value) => {if (value) platform.invokeMethod('show')});
  //   WidgetsBinding.instance.removeObserver(this);
  //   _signaling?.close();
  //   _signaling = null;
  //   _localRenderer.dispose();
  //   _remoteRenderer.dispose();
  //   hiLog(TAG, 'dispose');
  //   super.dispose();

  Icon? icon(int i, bool muted) => Icon(i == 0
      ? Icons.call_end
      : i == 1
          ? (muted ? Icons.mic_off : Icons.mic)
          : i == 2
              ? Icons.skip_next
              : Icons.block);

  VoidCallback? onPressed(int i, BuildContext context) {
    switch (i) {
      case 0:
        return Navigator.of(context).pop;
      case 1:
        return () => _chatBloc.ctr.add(Command.MUTE);
      case 2:
        return () => _chatBloc.ctr.add(Command.NEXT);
      case 3:
        return () => _block(context);
      default:
        return null;
    }
  }

  _block(BuildContext context) async {
    _chatBloc.ctr.add(Command.DIALOG);
    final res = await showDialog(
        context: context,
        builder: (_) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(content: Text(l10n?.block_report ?? 'You can block or report a complaint on this user'), actions: [
            TextButton(onPressed: Navigator.of(context).pop, child: Text(l10n?.cancel ?? 'Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, REPORT), child: Text(l10n?.complaint ?? 'Complaint')),
            TextButton(onPressed: () => Navigator.pop(context, BLOCK), child: Text(l10n?.block ?? 'BLOCK'))
          ]);
        });
    switch (res) {
      case BLOCK:
        _chatBloc.ctr.add(Command.BLOCK_PEER);
        break;
      case REPORT:
        _chatBloc.ctr.add(Command.REPORT);
        break;
      case null:
        _chatBloc.ctr.add(Command.DIALOG);
    }
  }

  void closeAndConnect() {
    print('close and connect');
  }

  _getBody(ChatState state, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width / 6;
    switch (state) {
      case ChatState.LOST:
        return const NoInternetWidget();
      case ChatState.UPDATE:
        return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(l10n?.must_update ?? 'You must update you app', style: const TextStyle(fontSize: 20)),
          ElevatedButton(onPressed: () => _chatBloc.platform.invokeMethod(UPDATE), child: Text(l10n?.update ?? 'UPDATE'))
        ]));
      case ChatState.WAITING:
        return const _WaitingWidget();
      case ChatState.MAINTENANCE:
        return const _MaintenanceWidget();
      case ChatState.IN_CALL:
        return SafeArea(
            child: Stack(alignment: Alignment.topCenter, fit: StackFit.expand, children: [
          RTCVideoView(_chatBloc.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ValueListenableBuilder(
              valueListenable: _chatBloc.localRenderer,
              builder: (ctx, RTCVideoValue v, ch) => Positioned(left: 0, width: width, height: width / v.aspectRatio, child: ch!),
              child: RTCVideoView(_chatBloc.localRenderer))
        ]));
    }
  }

  void _blockUser(BuildContext context) {
    _chatBloc.globalSink.add(GlobalEvent.BLOCK);
    Navigator.pop(context);
  }
}

class _MaintenanceWidget extends StatelessWidget {
  const _MaintenanceWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Center(
      child: Container(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Text(AppLocalizations.of(context)?.maintenance ?? 'Maintenance works on server side, come later please')));
}

class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[Text(AppLocalizations.of(context)?.err_conn ?? 'Connection error, try again please')]));
}

class _WaitingWidget extends StatelessWidget {
  static const _TAG = 'WaitingWidgetState';

  const _WaitingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const String viewType = 'medium_rectangle';
    final Map<String, dynamic> creationParams = <String, dynamic>{};
    final orientation = MediaQuery.of(context).orientation;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (Platform.isAndroid)
            SizedBox(
                height: 250,
                child: AndroidView(
                  viewType: viewType,
                  layoutDirection: TextDirection.ltr,
                  creationParams: creationParams,
                  creationParamsCodec: const StandardMessageCodec(),
                )),
          const Padding(padding: EdgeInsets.only(top: 5)),
          if (orientation == Orientation.portrait) const CircularProgressIndicator(),
          const Padding(padding: EdgeInsets.only(top: 10)),
          Text(AppLocalizations.of(context)?.waiting ?? 'Waiting for someone'),
        ],
      ),
    );
  }
}