// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/util/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_sign_up.dart';

class SignUpBloc extends BaseBloc<SignUpData, CmdSignUp> {
  static const _TAG = 'SignUpBloc';
  final txtCtrPhone = TextEditingController();
  late final List<TextEditingController> smsControllers;
  late String _verificationId;
  final txtCtrPass = TextEditingController();
  final txtCtrRePass = TextEditingController();

  SignUpBloc() {
    stream = _getStream();
    smsControllers = List.generate(6, (index) {
      final controller = TextEditingController();
      controller.addListener(() => _onTxtChanged(controller, index));
      return controller;
    });
    hiLog(_TAG, 'init');
  }

  Stream<SignUpData> _getStream() async* {
    hiLog(_TAG, 'get stream');
    final sp = await SharedPreferences.getInstance();
    final resendTime = sp.getInt(RESEND_TIME);
    var diff = 0;
    if (resendTime != null && (diff = (resendTime - DateTime.now().millisecondsSinceEpoch) ~/ 1000) > 10)
      ctr.add(CmdSignUp.TIMER);
    sp.remove(RESEND_TIME);
    var data = SignUpData(time: diff);
    await for (final cmd in ctr.stream)
      switch (cmd) {
        case CmdSignUp.SEND_NUM:
          yield data = data.copyWith(progress: true, phoneInvalid: false, tooMany: false);
          hiLog(_TAG, 'num:${txtCtrPhone.text}');
          _verify();
          break;
        case CmdSignUp.SMS:
          yield data = data.copyWith(progress: false, state: SignUpState.SMS, time: 60);
          break;
        case CmdSignUp.FOCUS_RIGHT:
          yield data = data.copyWith(focusIndex: data.focusIndex < 5 ? data.focusIndex + 1 : 5);
          break;
        case CmdSignUp.FOCUS_LEFT:
          yield data = data.copyWith(focusIndex: data.focusIndex > 0 ? data.focusIndex - 1 : 0);
          break;
        case CmdSignUp.BACK:
          for (final c in smsControllers.reversed) c.clear();
          yield data = data.copyWith(state: SignUpState.PHONE, progress: false, codeInvalid: false);
          break;
        case CmdSignUp.TIMER:
          if (data.time >= 0) {
            Future.delayed(const Duration(seconds: 1), () {
              data = data.copyWith(time: data.time - 1);
              ctr.add(CmdSignUp.TIMER);
            });
            if (data.state == SignUpState.PHONE) yield data;
          }
          break;
        case CmdSignUp.CHECK_TIME:
          if (data.time > 10) sp.setInt(RESEND_TIME, DateTime.now().add(Duration(seconds: data.time)).millisecondsSinceEpoch);
          break;
        case CmdSignUp.SUBMIT:
          yield data = data.copyWith(progress: true);
          final code = smsControllers.map((c) => c.text).join();
          PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: code);
          yield data = await _signIn(credential, data);
          break;
        case CmdSignUp.OBSCURE:
          yield data = data.copyWith(obscure: !data.obscure);
          break;
        case CmdSignUp.SAVE:
          yield data = data.copyWith(progress: true);
          yield data = await _save(txtCtrPhone.text, txtCtrPass.text, data);
          break;
        case CmdSignUp.PHONE_INVALID:
          yield data = data.copyWith(progress: false, phoneInvalid: true);
          break;
        case CmdSignUp.TOO_MANY:
          yield data = data.copyWith(progress: false, tooMany: true);
      }
  }

  _onTxtChanged(TextEditingController controller, int index) {
    hiLog(_TAG, 'on changed:${controller.text}');
    if (index == 0 && controller.text.isEmpty) return;
    const textSelection = TextSelection.collapsed(offset: 1);

    if (controller.text.isEmpty && index > 0) {
      smsControllers.elementAt(index - 1).selection = textSelection;
      ctr.add(CmdSignUp.FOCUS_LEFT);
    } else if (controller.text.length == 2 && index < 5) {
      final arr = controller.text.split('');
      controller.text = arr[0];
      final txtCtr = smsControllers.elementAt(index + 1);
      txtCtr.value = txtCtr.value.copyWith(text: arr[1], selection: textSelection);
      ctr.add(CmdSignUp.FOCUS_RIGHT);
    } else if (controller.text.length == 2)
      controller.value = controller.value.copyWith(text: controller.text.substring(0, 1), selection: textSelection);
    if (controller.text.length > 2) {
      final txt = controller.text;
      for (var i = 0; i < smsControllers.length; i++)
        smsControllers[i].value = controller.value.copyWith(text: txt[i], selection: textSelection);
    }
  }

  void _verify() => FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+${txtCtrPhone.text}',
      verificationCompleted: _completed,
      verificationFailed: _failed,
      codeSent: _sent,
      codeAutoRetrievalTimeout: _timeout);

  void _completed(PhoneAuthCredential cred) {
    hiLog(_TAG, 'completed');
    final smsCode = cred.smsCode;
    if (smsCode != null) {
      for (var i = 0; i < smsCode.length; i++) smsControllers[i].text = smsCode[i];
      ctr.add(CmdSignUp.SUBMIT);
    } else
      globalSink.add(GlobalEvent.ERR_CONN);
  }

  void _failed(FirebaseAuthException error) {
    hiLog(_TAG, 'failed:$error');
    if (error.code == 'invalid-phone-number')
      ctr.add(CmdSignUp.PHONE_INVALID);
    else if (error.code == 'too-many-requests') ctr.add(CmdSignUp.TOO_MANY);
  }

  void _sent(String verificationId, int? forceResendingToken) {
    hiLog(_TAG, 'sent:$verificationId');
    _verificationId = verificationId;
    ctr.add(CmdSignUp.SMS);
    ctr.add(CmdSignUp.TIMER);
  }

  void _timeout(String verificationId) {
    hiLog(_TAG, 'timeout:$verificationId');
  }

  Future<SignUpData> _signIn(PhoneAuthCredential credential, SignUpData data) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      return data.copyWith(state: SignUpState.SAVE, progress: false);
    } on FirebaseAuthException catch (e) {
      hiLog(_TAG, 'catch:$e');
      if (e.code == 'invalid-verification-code') return data.copyWith(progress: false, codeInvalid: true);
      globalSink.add(GlobalEvent.ERR_CONN);
    }
    return data.copyWith(progress: false, codeInvalid: false);
  }

  @override
  onLost() {}

  Future<SignUpData> _save(String login, String pass, SignUpData data) async {
    hiLog(_TAG, 'save:$login, $pass');
    final db = await dbGlobal;
    final sp = await SharedPreferences.getInstance();
    final passHash = md5.convert(utf8.encode(pass)).toString();
    final userMaps = (await db.query(USER, where: '$LOGIN=?', whereArgs: [login]));
    final docRef = FirebaseFirestore.instance.doc('$USER/$login');
    if (userMaps.isNotEmpty && userMaps.single[PASSWD] != passHash) {
      db.update(USER, {PASSWD: passHash}, where: '$LOGIN=?', whereArgs: [login]);
      docRef.update({PASSWD: passHash});
      await setSP(sp, login, userMaps.single[NAME] as String? ?? '');
    } else if (userMaps.isEmpty) {
      final doc = await docRef.get();
      final map = doc.data() ?? {};
      if (doc.exists && doc[PASSWD] != passHash) {
        docRef.update({PASSWD: passHash});
        db.insert(USER, {LOGIN: login, PASSWD: passHash, NAME: map[NAME]});
      } else if (!doc.exists) {
        docRef.set({PASSWD: passHash});
        db.insert(USER, {LOGIN: login, PASSWD: passHash});
      }
      hiLog(_TAG, 'map to save:$map');
      await setSPAndCache(sp, login, map);
    }
    if (await isBlocked(login, sp))
      globalSink.add(GlobalEvent.BLOCK);
    else
      globalSink.add(GlobalEvent.PROFILE);
    return data.copyWith(pop: true);
  }
}

enum CmdSignUp { SEND_NUM, SMS, FOCUS_RIGHT, FOCUS_LEFT, SUBMIT, BACK, TIMER, CHECK_TIME, OBSCURE, SAVE, PHONE_INVALID, TOO_MANY }
