// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/util/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_profile.dart';

class ProfileBloc extends BaseBloc<ProfileData, ProfileCmd> {
  static const _TAG = 'ProfileBloc';
  static const RESULT_PERMANENTLY_DENIED = 2;
  static const RESULT_GRANTED = 3;
  static const RESULT_DENIED = 4;
  final _blockedUsersStreamController = StreamController<String?>();
  final txtCtr = TextEditingController();
  late String _oldName;

  Sink<String?> get removeRefreshSink => _blockedUsersStreamController.sink;

  late final Stream<ProfileData> stream;
  late Stream<List<Map<String, Object?>>> blockedUsersStream;

  ProfileBloc() {
    stream = _getStream();
    blockedUsersStream = _getBlockedUsersStream();
  }

  @override
  onLost() {}

  Stream<List<Map<String, Object?>>> _getBlockedUsersStream() async* {
    final db = await dbGlobal;
    final sp = await SharedPreferences.getInstance();
    final login = sp.getString(LOGIN);
    var blockedPeers = (await db.query(BLOCKED_PEER, where: '$LOGIN=?', whereArgs: [login])).toList();
    hiLog(_TAG, 'blockedPeers: $blockedPeers');
    yield blockedPeers;
    await for (final peerLogin in _blockedUsersStreamController.stream) {
      if (peerLogin == null)
        blockedPeers = (await db.query(BLOCKED_PEER, where: '$LOGIN=?', whereArgs: [login])).toList(growable: true);
      else {
        db.delete(BLOCKED_PEER, where: '$PEER_LOGIN=? AND $LOGIN=?', whereArgs: [peerLogin, login]);
        FirebaseFirestore.instance.doc('$USER/$login/$BLOCKED_PEER/$peerLogin').delete();
        blockedPeers.removeWhere((peer) => peer[PEER_LOGIN] == peerLogin);
      }
      yield blockedPeers;
    }
  }

  Stream<ProfileData> _getStream() async* {
    ProfileData data;
    final sp = await SharedPreferences.getInstance();
    yield data = ProfileData(login: sp.getString(LOGIN)!);
    txtCtr.text = _oldName = sp.getString(NAME) ?? '';

    await for (final cmd in ctr.stream)
      switch (cmd) {
        case ProfileCmd.START:
          yield data = await _start(data);
      }
  }

  Future<ProfileData> _start(ProfileData data) async {
    if (txtCtr.text.isEmpty) return data.copyWith(nameEmpty: true, startChat: false);
    if (!BaseBloc.connectedToInet) {
      globalSink.add(GlobalEvent.NO_INTERNET);
      return data.copyWith(nameEmpty: false, startChat: false);
    }
    if (_oldName != txtCtr.text) {
      SharedPreferences.getInstance().then((sp) => sp.setString(NAME, txtCtr.text));
      FirebaseFirestore.instance.doc('$USER/${data.login}').update({NAME: txtCtr.text});
      (await dbGlobal).update(USER, {NAME: txtCtr.text}, where: '$LOGIN=?', whereArgs: [data.login]);
    }
    switch (await platform.invokeMethod('requestPermissions')) {
      case RESULT_PERMANENTLY_DENIED:
        globalSink.add(GlobalEvent.PERMISSION_PERMANENTLY_DENIED);
        return data.copyWith(nameEmpty: false);
      case RESULT_GRANTED:
        return data.copyWith(startChat: true, nameEmpty: false, name: txtCtr.text);
      case RESULT_DENIED:
        globalSink.add(GlobalEvent.PERMISSION_DENIED);
        return data.copyWith(nameEmpty: false);
    }
    return data;
  }

  // if (statuses.any((element) => element == PermissionStatus.denied)) globalSink.add(GlobalEvent.PERMISSION_NOT_GRANTED);
  // } else
  // return data.copyWith(startChat: true);

  Future<List<T>> multiFutureRes<T>(Iterable<Future<T>> iterable) => Future.wait(iterable);
// [
// Permission.camera, Permission.microphone].request().then((statuses) {
//     hiLog(_TAG, 'statuses=>$statuses');
//     final denied = Map.from(statuses)..removeWhere((key, value) => value != PermissionStatus.permanentlyDenied);
//     hiLog(_TAG, 'denied: $denied');
//     if (denied.isNotEmpty)
//       globalSink.add(GlobalEvent.PERMISSION_PERMANENTLY_DENIED);
//     else if (statuses.values.any((e) => !e.isGranted))
//       globalSink.add(GlobalEvent.PERMISSION_NOT_GRANTED);

}

enum ProfileCmd { START }
