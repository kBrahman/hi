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
  final _blockedUsersStreamController = StreamController<String?>();
  final txtCtr = TextEditingController();

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
    final oldName = txtCtr.text = sp.getString(NAME) ?? '';
    await for (final cmd in ctr.stream)
      switch (cmd) {
        case ProfileCmd.UPDATE:
          if (oldName != txtCtr.text) {
            SharedPreferences.getInstance().then((sp) => sp.setString(NAME, txtCtr.text));
            FirebaseFirestore.instance.doc('$USER/${data.login}').update({NAME: txtCtr.text});
            (await dbGlobal).update(USER, {NAME: txtCtr.text}, where: '$LOGIN=?', whereArgs: [data.login]);
          }
          break;
        case ProfileCmd.NAME_EMPTY:
          yield data = data.copyWith(nameEmpty: true);
      }
  }

// if (statuses.any((element) => element == PermissionStatus.denied)) globalSink.add(GlobalEvent.PERMISSION_NOT_GRANTED);
// } else

}

enum ProfileCmd { UPDATE, NAME_EMPTY }
