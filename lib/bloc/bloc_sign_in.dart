// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/util/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_sign_in.dart';

class SignInBloc extends BaseBloc {
  static const _TAG = 'SignInBloc';
  final txtCtrLogin = TextEditingController();
  final txtCtrPass = TextEditingController();
  final _ctr = StreamController<Command>();
  late final Stream<SignInData> stream;

  Sink<Command> get sink => _ctr.sink;

  SignInBloc() {
    stream = _getStream();
  }

  Stream<SignInData> _getStream() async* {
    var data = const SignInData();
    await for (final cmd in _ctr.stream)
      switch (cmd) {
        case Command.OBSCURE:
          yield data = data.copyWith(obscure: !data.obscure);
          break;
        case Command.SIGN_IN:
          yield data = data.copyWith(progress: true);
          yield data = await _signIn(data);
      }
  }

  Future<SignInData> _signIn(SignInData data) async {
    if (!BaseBloc.connectedToInet) {
      globalSink.add(GlobalEvent.NO_INTERNET);
      return data;
    }
    final login = txtCtrLogin.text;
    hiLog(_TAG, 'signIn: $login');
    if (!RegExp(r'(^\d+$)').hasMatch(login)) return data.copyWith(loginInvalid: true, progress: false);
    final docRef = FirebaseFirestore.instance.doc('$BLOCKED_USER/$login');
    final DocumentSnapshot docBlocked;
    try {
      docBlocked = await docRef.get();
    } on FirebaseException {
      globalSink.add(GlobalEvent.ERR_CONN);
      return data.copyWith(progress: false);
    }
    hiLog(_TAG, 'got docBlocked: ${docBlocked.exists}');
    final sp = await SharedPreferences.getInstance();
    if (docBlocked.exists) {
      final blockTime = (docBlocked[BLOCK_TIME] as Timestamp).millisecondsSinceEpoch;
      final index = docBlocked[BLOCK_PERIOD_INDEX];
      final blockPeriod = getMilliseconds(BlockPeriod.values[index]);
      if (blockPeriod == 0 || DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(blockTime + blockPeriod))) {
        await Future.wait([sp.setBool(IS_BLOCKED, true), sp.setInt(BLOCK_TIME, blockTime), sp.setInt(BLOCK_PERIOD_INDEX, index)]);
        hiLog(_TAG, 'signIn: blocked, block code: $index');
        globalSink.add(GlobalEvent.BLOCK);
      } else {
        await Future.wait(
            [sp.remove(IS_BLOCKED), sp.remove(BLOCK_TIME), sp.remove(BLOCK_PERIOD_INDEX), sp.setString(LOGIN, login)]);
        globalSink.add(GlobalEvent.PROFILE);
      }
    } else {
      hiLog(_TAG, 'in else');
      final db = await dbGlobal;
      final userMaps = await db.query(USER, where: '$LOGIN=?', whereArgs: [login]);
      hiLog(_TAG, 'user maps=>$userMaps');
      if (userMaps.isNotEmpty) {
        final userMap = userMaps.first;
        hiLog(_TAG, 'getting user from DB=>$userMap');
        if (userMap[PASSWD] != md5.convert(utf8.encode(txtCtrPass.text)).toString())
          return data.copyWith(progress: false, passLoginWrong: true);
        await Future.wait(
            [sp.setBool(IS_SIGNED_IN, true), sp.setString(LOGIN, login), sp.setString(NAME, userMap[NAME] as String)]);
        globalSink.add(GlobalEvent.PROFILE);
      } else {
        hiLog(_TAG, 'getting from cloud');
        final userDoc = await FirebaseFirestore.instance.doc('$USER/$login').get();
        if (!userDoc.exists || userDoc[PASSWD] != md5.convert(utf8.encode(txtCtrPass.text)).toString())
          return data.copyWith(progress: false, passLoginWrong: true);
        final map = userDoc.data() ?? {};
        hiLog(_TAG, 'doc data=>$map');
        db.insert(USER, {LOGIN: login, PASSWD: userDoc[PASSWD], NAME: map[NAME]});
        try {
          await Future.wait([
            sp.setBool(IS_SIGNED_IN, true),
            sp.setString(LOGIN, login),
            sp.setString(NAME, map[NAME] ?? ''),
            _cacheBlockedPeers(login),
            _cacheReports(login)
          ]);
        } catch (e) {
          hiLog(_TAG, 'cache catch:$e');
        }
        globalSink.add(GlobalEvent.PROFILE);
      }
    }
    return data;
    // final DocumentSnapshot<Map<String, dynamic>> docBlocked;
    // if (res.isNotEmpty || ((docBlocked = await FirebaseFirestore.instance.docBlocked('user/$_login').get()).exists && docBlocked[PASSWD] == passHash))
    //   _loginContinue(_login, context, false);
    // else {
    //   _loginOrPassWrong = true;
  }

  Future<bool> _cacheBlockedPeers(String login) {
    hiLog(_TAG, '_cacheBlockedPeers');
    return FirebaseFirestore.instance.collection('$USER/$login/$BLOCKED_PEER').get().then((collection) {
      final docs = collection.docs;
      hiLog(_TAG, 'docs len=>${docs.length}');
      return Future.wait(docs.map((doc) => _saveDoc(BLOCKED_PEER, {PEER_LOGIN: doc.id, LOGIN: login, NAME: doc[NAME]})));
    }).then((_) => true);
  }

  Future<bool> _cacheReports(String login) =>
      FirebaseFirestore.instance.collection('$USER/$login/$REPORT').get().then((collection) {
        final docs = collection.docs;
        hiLog(_TAG, 'reps len=>${docs.length}');
        return Future.wait(docs.map((doc) => _saveDoc(REPORT, {PEER_LOGIN: doc.id, LOGIN: login})));
      }).then((_) => true);

  _saveDoc(table, data) async => dbGlobal.then((db) => db.insert(table, data));
}

enum Command { SIGN_IN, OBSCURE }
