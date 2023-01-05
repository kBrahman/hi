// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/data/data_email_sign_in.dart';
import 'package:hi/util/util.dart';

class EmailSignInBloc extends BaseBloc<EmailSignInData, Cmd> {
  static const _TAG = 'EmailSignInBloc';
  final txtCtrEmail = TextEditingController();

  EmailSignInBloc() {
    stream = _getStream();
  }

  Stream<EmailSignInData> _getStream() async* {
    var data = const EmailSignInData();
    await for (final cmd in ctr.stream)
      switch (cmd) {
        case Cmd.SIGN_IN:
          yield data = data.copyWith(progress: true);
          if (!BaseBloc.connectedToInet) {
            globalSink.add(GlobalEvent.NO_INTERNET);
            yield data = data.copyWith(progress: false);
          } else if (RegExp(r'(mail.ru|bk.ru|list.ru|internet.ru|inbox.ru)').hasMatch(txtCtrEmail.text)) {
            globalSink.add(GlobalEvent.ERR_MAIL_RU);
            yield data = data.copyWith(progress: false);
          } else if (!_valid(txtCtrEmail.text))
            yield data = data.copyWith(progress: false, emailInvalid: true);
          else
            yield data = await _emailSignIn(txtCtrEmail.text, data);
      }
  }

  bool _valid(String email) => email.contains('.') && email.contains('@');
  @override
  onLost() {

  }
  Future<EmailSignInData> _emailSignIn(email, EmailSignInData data) async {

    var instance = FirebaseAuth.instance;
    var id = await platform.invokeMethod('getPackageName');
    final actionCodeSettings = ActionCodeSettings(
        dynamicLinkDomain: 'zhethi.page.link',
        url: 'https://zhethi.page.link/signIn?login=$email',
        androidPackageName: id,
        androidInstallApp: true,
        iOSBundleId: id,
        handleCodeInApp: true,
        androidMinimumVersion: '3');
    try {
      await instance.sendSignInLinkToEmail(email: email, actionCodeSettings: actionCodeSettings);
    } catch (e) {
      hiLog(_TAG, 'catch:$e');
    }
    // showSnack(locs?.email_send_err ?? 'Could not send and email, try again please', 5, ctx);
    return data.copyWith(progress: false, emailSent: true);
  }
}

enum Cmd { SIGN_IN }
