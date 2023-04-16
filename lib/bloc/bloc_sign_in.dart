// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/util/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_sign_in.dart';

class SignInBloc extends BaseBloc<SignInData, Command> {
  static const _TAG = 'SignInBloc';
  final txtCtrLogin = TextEditingController();
  final txtCtrPass = TextEditingController();

  SignInBloc() {
    _dynamicLink();
    stream = _getStream();
    FirebaseAuth.instance.setLanguageCode(Platform.localeName.substring(0, 2));
  }

  void _dynamicLink() =>
      FirebaseDynamicLinks.instance.getInitialLink().then((link) {
        if (link == null) return;
        final login = Uri.parse(link.link.queryParameters['continueUrl']!)
                .queryParameters['login'] ??
            '';
        hiLog(_TAG, 'login=>$login');
        ctr.add(Command.PROGRESS);
        _saveAndCheck(login, const SignInData());
      });

  Stream<SignInData> _getStream() async* {
    var data = const SignInData();
    await for (final cmd in ctr.stream)
      switch (cmd) {
        case Command.OBSCURE:
          yield data = data.copyWith(obscure: !data.obscure);
          break;
        case Command.SIGN_IN:
          yield data = data.copyWith(progress: true);
          yield data = await _signIn(data);
          break;
        case Command.SIGN_IN_GOOGLE:
          yield data = data.copyWith(progress: true);
          yield data = await _googleSignIn(data);
          break;
        case Command.PROGRESS:
          yield data = data.copyWith(progress: true);
      }
  }

  @override
  onLost() {}

  Future<SignInData> _googleSignIn(SignInData data) async {
    if (!BaseBloc.connectedToInet) {
      globalSink.add(GlobalEvent.NO_INTERNET);
      return data.copyWith(progress: false);
    }
    GoogleSignIn googleSignIn = GoogleSignIn(scopes: <String>['email']);
    var login = googleSignIn.currentUser?.email;
    try {
      if (login == null &&
          (login = (await googleSignIn.signInSilently())?.email) == null) {
        final acc = await googleSignIn.signIn();
        login = acc?.email;
      }
      if (login == null) {
        globalSink.add(GlobalEvent.ERR_CONN);
        return data.copyWith(progress: false);
      }
    } catch (e) {
      if (e is PlatformException && e.message == 'network_error') {
        globalSink.add(GlobalEvent.ERR_CONN);
        return data.copyWith(progress: false);
      }
      var ex = e as PlatformException;
      hiLog(_TAG, 'google sign in exception:${ex.code}');
    }
    return _saveAndCheck(login!, data);
  }

  Future<SignInData> _saveAndCheck(String login, SignInData data) async {
    final db = await dbGlobal;
    final userMaps =
        await db.query(USER, where: '$LOGIN=?', whereArgs: [login]);
    final sp = await SharedPreferences.getInstance();
    hiLog(_TAG, 'user maps=>$userMaps');
    if (userMaps.isNotEmpty) {
      final userMap = userMaps.first;
      hiLog(_TAG, 'getting user from DB=>$userMap');
      await setSP(sp, login, userMap[NAME] as String? ?? '');
      globalSink.add(GlobalEvent.PROFILE);
      return data.copyWith(progress: false);
    }
    final userDoc = await FirebaseFirestore.instance.doc('$USER/$login').get();
    final Map userMap;
    if (!userDoc.exists) {
      FirebaseFirestore.instance.doc('$USER/$login').set({});
      userMap = {};
    } else
      userMap = userDoc.data()!;
    db.insert(USER, {LOGIN: login, NAME: userMap[NAME]});
    await setSPAndCache(sp, login, userMap);
    if (await isBlocked(login, sp))
      globalSink.add(GlobalEvent.BLOCK);
    else
      globalSink.add(GlobalEvent.PROFILE);
    return data.copyWith(progress: false);
  }

  Future<SignInData> _signIn(SignInData data) async {
    final login = txtCtrLogin.text;
    hiLog(_TAG, 'signIn: $login');
    if (!BaseBloc.connectedToInet) {
      globalSink.add(GlobalEvent.NO_INTERNET);
      return data.copyWith(progress: false);
    }
    if (!RegExp(r'(^\d+$)').hasMatch(login))
      return data.copyWith(loginInvalid: true, progress: false);
    final db = await dbGlobal;
    final userMaps =
        await db.query(USER, where: '$LOGIN=?', whereArgs: [login]);
    final sp = await SharedPreferences.getInstance();
    hiLog(_TAG, 'user maps=>$userMaps');
    if (userMaps.isNotEmpty) {
      final userMap = userMaps.first;
      hiLog(_TAG, 'getting user from DB=>$userMap');
      if (userMap[PASSWD] !=
          md5.convert(utf8.encode(txtCtrPass.text)).toString())
        return data.copyWith(progress: false, passLoginWrong: true);
      await setSP(sp, login, userMap[NAME] as String? ?? '');
    } else {
      final userDoc =
          await FirebaseFirestore.instance.doc('$USER/$login').get();
      if (!userDoc.exists ||
          userDoc[PASSWD] !=
              md5.convert(utf8.encode(txtCtrPass.text)).toString())
        return data.copyWith(progress: false, passLoginWrong: true);
      final map = userDoc.data() ?? {};
      hiLog(_TAG, 'doc data=>$map');
      db.insert(USER, {LOGIN: login, PASSWD: userDoc[PASSWD], NAME: map[NAME]});
      await setSPAndCache(sp, login, map);
    }
    try {
      if (await isBlocked(login, sp))
        globalSink.add(GlobalEvent.BLOCK);
      else
        globalSink.add(GlobalEvent.PROFILE);
    } catch (e) {
      hiLog(_TAG, 'catch while checking block status, e:$e');
      globalSink.add(GlobalEvent.ERR_CONN);
    }
    return data.copyWith(progress: false);
  }
}

enum Command { SIGN_IN, OBSCURE, SIGN_IN_GOOGLE, PROGRESS }
