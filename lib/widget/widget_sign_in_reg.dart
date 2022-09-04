// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hi/widget/widget_btn.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../util/util.dart';

class SignInOrRegWidget extends StatefulWidget {
  final Function(String) onSuccess;
  final bool _connectedToInet;
  final Function(String, DateTime, int) onBlocked;
  final Function(String lgin) onSetPassd;

  const SignInOrRegWidget(this.onSuccess, this.onBlocked, this.onSetPassd, this._connectedToInet, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SignInOrUpState();
}

class _SignInOrUpState extends State<SignInOrRegWidget> with WidgetsBindingObserver {
  static const TAG = 'SignInState';
  var _passEmptyErr = false;
  var _loginEmptyErr = false;
  String _login = '';
  bool _signUp = false;
  var _showVerificationForm = false;
  var _newLogin = '';
  var _newLoginEmpty = false;
  var _formatErr = false;
  var verificationCode = List.filled(6, '');
  var _registeringWithPhone = true;
  var showCodeSent = false;
  var showErr = false;
  int _remainingTimeToResend = 0;
  var _timerStarted = false;
  final phoneKey = UniqueKey();
  final emailKey = UniqueKey();
  var focusIndex = 0;
  UniqueKey? currKey;
  late String _verificationId;
  final auth = FirebaseAuth.instance;
  var obscure = true;
  String _pass = '';
  var _showProgress = false;
  var _loginOrPassWrong = false;
  var _emailSignUpErr = false;
  late BuildContext ctx;
  bool _showLoading = false;

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
        {
          hiLog(TAG, 'saving state verification code=>$verificationCode');
          final p = await SharedPreferences.getInstance();
          final data = [_verificationId, verificationCode.join(':'), _newLogin];
          if (_remainingTimeToResend > 0) {
            final currTime = currentTimeInSec();
            data.add('$currTime:$_remainingTimeToResend');
          }
          final res = await p.setStringList(VERIFICATION_DATA, data);
          hiLog(TAG, 'finished saving state, result ok=>$res');
        }
    }
  }

  int currentTimeInSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  @override
  void initState() {
    _checkVerificationStateAndDynamicLink();
    auth.setLanguageCode(Platform.localeName.substring(0, 2));
    super.initState();
  }

  _checkVerificationStateAndDynamicLink() async {
    final sp = await SharedPreferences.getInstance();
    if (sp.containsKey(VERIFICATION_DATA)) {
      final data = sp.getStringList(VERIFICATION_DATA)!;
      hiLog(TAG, 'data in init=>$data');
      _verificationId = data[0];
      _newLogin = data[2];
      if (data.length == 4) {
        final times = data[3].split(':');
        final timestamp = int.parse(times[0]);
        final timeToResend = int.parse(times[1]);
        final currTime = currentTimeInSec();
        if (currTime - timestamp > timeToResend)
          _remainingTimeToResend = 0;
        else {
          _remainingTimeToResend = timeToResend - currTime + timestamp;
          _timerStarted = true;
          startTimer();
        }
      }
      setState(() {
        verificationCode = data[1].split(':');
        focusIndex = verificationCode.indexOf('') - 1;
        _showVerificationForm = true;
        showCodeSent = true;
        currKey = UniqueKey();
      });
    } else
      FirebaseDynamicLinks.instance.getInitialLink().then((link) {
        if (link == null) return;
        _login = Uri.parse(link.link.queryParameters['continueUrl']!).queryParameters['login'] ?? '';
        hiLog(TAG, 'login=>$_login');
        if (_login.isEmpty) {
          setState(() {
            _emailSignUpErr = true;
          });
        } else
          _loginContinue(_login, ctx, true);
      });
  }

  @override
  Widget build(BuildContext context) {
    ctx = context;
    return Scaffold(
        appBar: AppBar(
            title: nameWidget,
            bottom: _showProgress
                ? const PreferredSize(
                    preferredSize: Size(double.infinity, 0), child: LinearProgressIndicator(backgroundColor: Colors.white))
                : null),
        body: getChild(context));
  }

  Widget getChild(BuildContext context) {
    final locs = AppLocalizations.of(context);
    return _showLoading
        ? const Center(child: CircularProgressIndicator())
        : _showVerificationForm
            ? Center(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showCodeSent)
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text((locs?.sms ?? 'SMS is sent to') + ' +$_newLogin'),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(locs?.you_can ?? 'You can'),
                        InkWell(
                            child: Text(' ' + (locs?.resend ?? 'resend') + ' ', style: const TextStyle(color: Colors.red)),
                            onTap: () => register(context)),
                        Text(locs?.after ?? 'after: '),
                        Text('$_remainingTimeToResend secs')
                      ])
                    ]),
                  Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(6, (index) {
                        var enabled = focusIndex == 6 || index == focusIndex;
                        var c = verificationCode[index];
                        return Row(children: [
                          if (index > 0) sizedBox_w_4,
                          SizedBox(
                              width: 40,
                              child: TextField(
                                  key: (index == focusIndex) ? currKey : null,
                                  enabled: enabled,
                                  controller: TextEditingController(text: c)
                                    ..selection = TextSelection(baseOffset: c.length, extentOffset: c.length),
                                  onChanged: (txt) {
                                    if (txt.length == 6)
                                      setState(() => verificationCode = txt.split(''));
                                    else if (txt.length == 2 && index < 5)
                                      setState(() {
                                        verificationCode[index + 1] = txt.characters.last;
                                        focusIndex = index + 1;
                                      });
                                    else if (txt.isEmpty)
                                      setState(() {
                                        verificationCode[index] = '';
                                        focusIndex = focusIndex > 0 ? index - 1 : focusIndex;
                                      });
                                    else
                                      setState(() {
                                        verificationCode[index] = txt[0];
                                        focusIndex = index;
                                      });
                                  },
                                  autofocus: showCodeSent && enabled,
                                  showCursor: false,
                                  style: const TextStyle(fontSize: 30),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number))
                        ]);
                      })),
                  sizedBox_h_8,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                          onPressed: verificationCode.any((e) => e.isEmpty) ? null : submit,
                          child: Text(locs?.submit ?? 'SUBMIT')),
                      sizedBox_w_8,
                      ElevatedButton(
                          onPressed: showCodeSent || showErr
                              ? () {
                                  SharedPreferences.getInstance().then((p) => p.remove(VERIFICATION_DATA));
                                  setState(() {
                                    _showVerificationForm = false;
                                    showCodeSent = false;
                                    focusIndex = 0;
                                  });
                                  for (int i = 0; i < verificationCode.length; i++) verificationCode[i] = '';
                                  WidgetsBinding.instance.removeObserver(this);
                                }
                              : null,
                          child: Text(locs?.cancel ?? 'CANCEL'))
                    ],
                  )
                ],
              ))
            : _signUp
                ? Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                            key: _registeringWithPhone ? phoneKey : emailKey,
                            autofocus: true,
                            onChanged: (String txt) {
                              _newLogin = txt;
                            },
                            controller: TextEditingController(text: _newLogin)
                              ..selection = TextSelection(baseOffset: _newLogin.length, extentOffset: _newLogin.length),
                            decoration: InputDecoration(
                                prefixText: _registeringWithPhone ? '+' : '',
                                hintText: _registeringWithPhone
                                    ? locs?.phone ?? 'Enter your phone number'
                                    : locs?.email ?? 'Enter your email'),
                            keyboardType: _registeringWithPhone ? TextInputType.number : TextInputType.emailAddress,
                            inputFormatters: _registeringWithPhone ? [FilteringTextInputFormatter.digitsOnly] : null,
                          ),
                          if (_newLoginEmpty)
                            Text(locs?.required ?? "This field is required",
                                style: const TextStyle(fontSize: 13, color: Colors.red))
                          else if (_formatErr)
                            Text(locs?.format_err ?? "Format is wrong", style: const TextStyle(fontSize: 13, color: Colors.red)),
                          sizedBox_h_8,
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                  onPressed: !_timerStarted ? () => onNext(context) : null, child: Text(locs?.next ?? 'NEXT')),
                              sizedBox_w_4,
                              ElevatedButton(
                                  onPressed: () => setState(() {
                                        _signUp = false;
                                        _showVerificationForm = false;
                                        _login = '';
                                        _newLogin = '';
                                        _formatErr = false;
                                      }),
                                  child: Text(locs?.cancel ?? 'CANCEL'))
                            ],
                          ),
                          if (_timerStarted)
                            Text((locs?.can_send_after ?? 'You can send after:') + ' $_remainingTimeToResend secs')
                        ])))
                : Center(
                    child: SizedBox(
                        width: 220,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (_loginOrPassWrong)
                            Text(locs?.pass_login_wrong ?? 'Login or password is wrong',
                                style: const TextStyle(color: Colors.red))
                          else if (_emailSignUpErr)
                            Text(locs?.sign_in_problem ?? 'Could not sign in with email, try again please',
                                style: const TextStyle(fontSize: 13, color: Colors.red)),
                          TextField(
                              style: const TextStyle(fontSize: 20),
                              onChanged: (String txt) {
                                if (txt.startsWith('+'))
                                  setState(() => _login = txt.substring(1));
                                else
                                  _login = txt;
                              },
                              textInputAction: TextInputAction.next,
                              controller: TextEditingController(text: _login),
                              decoration: InputDecoration(
                                  hintText: locs?.phone ?? 'phone number',
                                  prefixText: '+',
                                  prefixStyle: const TextStyle(color: Colors.black, fontSize: 20))),
                          if (_loginEmptyErr)
                            Text(locs?.required ?? 'This field is required',
                                style: const TextStyle(fontSize: 13, color: Colors.red)),
                          TextField(
                            style: const TextStyle(fontSize: 20),
                            obscureText: obscure,
                            onChanged: (String txt) => _pass = txt,
                            controller: TextEditingController(text: _pass)
                              ..selection = TextSelection(baseOffset: _pass.length, extentOffset: _pass.length),
                            decoration: InputDecoration(
                                hintText: locs?.passwd ?? 'password',
                                suffixIcon: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        obscure = !obscure;
                                      });
                                    },
                                    child: const Icon(Icons.remove_red_eye))),
                            onSubmitted: (txt) => signIn(context),
                          ),
                          if (_passEmptyErr)
                            Text(locs?.required ?? "This field is required",
                                style: const TextStyle(fontSize: 13, color: Colors.red)),
                          sizedBox_h_8,
                          HiBtn(
                            () => _login.isEmpty
                                ? setState(() => _loginEmptyErr = true)
                                : _pass.isEmpty
                                    ? setState(() {
                                        _passEmptyErr = true;
                                        _loginEmptyErr = false;
                                      })
                                    : signIn(context),
                            locs?.sign_in ?? 'Sign in',
                            Icons.done,
                            const Color.fromRGBO(0, 0, 0, 0.54),
                          ),
                          SignInButton(Buttons.Google, text: locs?.sign_in_google, onPressed: () => googleSignIn(context)),
                          HiBtn(() {
                            setState(() {
                              _signUp = true;
                              _registeringWithPhone = false;
                            });
                          }, locs?.sign_in_email ?? 'Sign in with email', null, const Color.fromRGBO(0, 0, 0, 0.54)),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: HiBtn(_register, locs?.create ?? 'CREATE NEW ACCOUNT', null, Colors.black),
                          ),
                          InkWell(
                              child: Text(locs?.forgot ?? 'I forgot my password', style: const TextStyle(color: Colors.red)),
                              onTap: _register)
                        ])));
  }

  void _register() {
    if (!_showProgress)
      setState(() {
        _signUp = true;
        _registeringWithPhone = true;
      });
  }

  void register(context) {
    if (_remainingTimeToResend > 0) return;
    if (_registeringWithPhone)
      phoneSignUp();
    else if (RegExp(r'^([^&])+@([^&])+\.([^&])+$').hasMatch(_newLogin)) {
      setState(() {
        _formatErr = false;
        _newLoginEmpty = false;
      });
      emailSignUp();
    } else
      setState(() {
        _formatErr = true;
        _newLoginEmpty = false;
      });
  }

  emailSignUp() async {
    if (_showProgress) return;
    final locs = AppLocalizations.of(ctx);
    if (RegExp(r'(mail.ru|bk.ru|list.ru|internet.ru|inbox.ru)').hasMatch(_newLogin))
      return showSnack(locs?.mail_ru_problem ?? 'Email sign in does not work with mail.ru, try other email please', 5, ctx);
    showProgress(true);
    try {
      var instance = FirebaseAuth.instance;
      var id = await getId();
      final actionCodeSettings = ActionCodeSettings(
          dynamicLinkDomain: 'zhethi.page.link',
          url: 'https://zhethi.page.link/signIn?login=$_newLogin',
          androidPackageName: id,
          androidInstallApp: true,
          iOSBundleId: id,
          handleCodeInApp: true,
          androidMinimumVersion: '2');
      await instance.sendSignInLinkToEmail(email: _newLogin, actionCodeSettings: actionCodeSettings);
    } on FirebaseAuthException catch (e) {
      showSnack(locs?.email_send_err ?? 'Could not send and email, try again please', 5, ctx);
      return;
    } finally {
      showProgress(false);
    }
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Row(children: [
          Expanded(child: Text(locs?.email_sent(_newLogin) ?? 'Email is sent to $_newLogin.  Check SPAM also.')),
          TextButton(onPressed: openEmail, child: Text(locs?.open ?? 'OPEN'))
        ]),
        duration: const Duration(seconds: 11)));
  }

  void showProgress(bool b) => setState(() => _showProgress = b);

  Future<String?> getId() => platform.invokeMethod('getPackageName');

  phoneSignUp() async {
    final locs = AppLocalizations.of(ctx);
    if (_newLogin.length < 4 || _newLogin.length > 15) {
      _newLoginEmpty = false;
      if (!_formatErr) setState(() => _formatErr = true);
    } else if (widget._connectedToInet) {
      showProgress(true);
      await auth.verifyPhoneNumber(
          phoneNumber: '+' + _newLogin,
          verificationCompleted: (PhoneAuthCredential cred) {
            hiLog(TAG, 'verification completed, cred=>$cred');
            setState(() {
              verificationCode = cred.smsCode!.split('');
              _showProgress = false;
            });
            submit();
          },
          verificationFailed: (e) {
            hiLog(TAG, 'failed=>$e, code=>${e.code}');
            if (e.code == "too-many-requests")
              showSnack(locs?.ip_blocked ?? 'Your IP has been temporarily blocked. Try again later please', 4, ctx);
            else if (e.code == 'invalid-phone-number') {
              showSnack(locs?.phone_invalid ?? 'Invalid phone number', 4, ctx);
              setState(() => _showVerificationForm = false);
            } else if (e.code == 'web-internal-error')
              showSnack(locs?.internal_err ?? 'There was an internal error, try again later please', 4, context);
            else if (e.code == 'app-not-authorized')
              showSnack(locs?.phone_unavailable ?? 'Phone sign up is currently not working, try other method please', 4, ctx);
            showErr = true;
            showProgress(false);
          },
          codeSent: (id, token) {
            showProgress(false);
            showCodeSent = true;
            _timerStarted = true;
            _remainingTimeToResend = 120;
            currKey = UniqueKey();
            startTimer();
            _verificationId = id;
            WidgetsBinding.instance.addObserver(this);
          },
          codeAutoRetrievalTimeout: (id) {});
      setState(() {
        _showVerificationForm = true;
        _formatErr = false;
      });
    } else
      showSnack(locs?.no_inet ?? 'No internet', 1, ctx);
  }

  submit() async {
    if (_showProgress) return;
    showProgress(true);
    SharedPreferences.getInstance().then((p) => p.remove(VERIFICATION_DATA));
    PhoneAuthCredential credential =
        PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: verificationCode.join());
    auth.signInWithCredential(credential).then((value) {
      _timerStarted = false;
      _login = _newLogin;
      widget.onSetPassd(_login);
    }, onError: (e) {
      if (e is FirebaseAuthException && e.code == 'invalid-verification-code') {
        showSnack(AppLocalizations.of(ctx)?.sms_invalid ?? 'Invalid SMS code', 2, ctx);
        showProgress(false);
      }
    });
    WidgetsBinding.instance.removeObserver(this);
  }

  googleSignIn(BuildContext context) async {
    if (_showProgress) return;
    if (widget._connectedToInet) {
      GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email']);
      var login = _googleSignIn.currentUser?.email;
      if (login == null && (login = (await _googleSignIn.signInSilently())?.email) == null) {
        final acc = await _googleSignIn.signIn();
        login = acc?.email;
      }
      if (login != null) _loginContinue(login, context, false);
    } else
      showSnack(AppLocalizations.of(ctx)?.no_inet ?? 'No internet', 1, context);
  }

  _loginContinue(String login, BuildContext context, fromDLink) async {
    if (fromDLink)
      setState(() => _showLoading = true);
    else
      showProgress(true);
    final sp = await SharedPreferences.getInstance();
    final db = await openDatabase(join(await getDatabasesPath(), DB_NAME), version: DB_VERSION_1);
    sp.setString(LOGIN, login);
    sp.setBool(SIGNED_IN, true);
    final List<Map<String, Object?>> res;
    final data =
        (res = await db.query(TABLE_USER, columns: [BLOCK_PERIOD, BLOCK_TIME], where: '$LOGIN=?', whereArgs: [login])).isNotEmpty
            ? res.first
            : {};
    final blockPeriod = data[BLOCK_PERIOD] ?? BLOCK_NO;
    final blockTime = data[BLOCK_TIME];
    DateTime unblockTime;
    final DocumentSnapshot doc;
    try {
      if (blockPeriod != BLOCK_NO &&
          DateTime.now().isBefore(
              unblockTime = DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod)))))
        return widget.onBlocked(login, unblockTime, blockPeriod);
      else if (blockPeriod != BLOCK_NO &&
          DateTime.now()
              .isAfter(DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod))))) {
        db.update(TABLE_USER, {BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: blockPeriod}, where: '$LOGIN=?', whereArgs: [login]);
        FirebaseFirestore.instance.doc('user/$login').set(
            {BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: blockPeriod, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0)},
            SetOptions(merge: true));
      } else if (!(doc = await FirebaseFirestore.instance.doc('user/$login').get()).exists) {
        FirebaseFirestore.instance
            .doc('user/$login')
            .set({BLOCK_PERIOD: BLOCK_NO, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0), LAST_BLOCK_PERIOD: BLOCK_NO});
        db.insert(TABLE_USER, {LOGIN: login});
      } else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
          DateTime.now().isBefore(
              unblockTime = (doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD]))))) {
        sp.setInt(BLOCK_PERIOD, doc[BLOCK_PERIOD]);
        final millis = (doc[BLOCK_TIME] as Timestamp).millisecondsSinceEpoch;
        sp.setInt(BLOCK_TIME, millis);
        db.insert(TABLE_USER,
            {LOGIN: login, BLOCK_PERIOD: doc[BLOCK_PERIOD], BLOCK_TIME: millis, LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD]});
        return widget.onBlocked(login, unblockTime, doc[BLOCK_PERIOD]);
      } else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
          DateTime.now().isAfter((doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD]))))) {
        FirebaseFirestore.instance.doc('user/$login').set(
            {BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: blockPeriod, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0)},
            SetOptions(merge: true));
        db.insert(TABLE_USER, {
          LOGIN: login,
          BLOCK_PERIOD: BLOCK_NO,
          BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0),
          LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD]
        });
      } else if (data.isEmpty) db.insert(TABLE_USER, {LOGIN: login});
    } catch (e) {
      showSnack(AppLocalizations.of(context)?.err_conn ?? 'Connection error, try again please', 2, context);
      setState(() => _showProgress = false);
      return;
    }
    updateDBWithBlockedUsersAndReporters(db, login);
    widget.onSuccess(login);
  }

  signIn(BuildContext context) async {
    if (_showProgress) return;
    if (!RegExp(r'(\d+$)').hasMatch(_login)) {
      setState(() {
        _loginOrPassWrong = true;
        _passEmptyErr = false;
      });
      return;
    }
    showProgress(true);
    final db = await openDatabase(join(await getDatabasesPath(), DB_NAME), version: DB_VERSION_1);
    final passHash = md5.convert(utf8.encode(_pass)).toString();
    final res =
        await db.query(TABLE_USER, columns: [LOGIN, PASSWD], where: '$LOGIN=? AND $PASSWD=?', whereArgs: [_login, passHash]);
    final DocumentSnapshot<Map<String, dynamic>> doc;
    if (res.isNotEmpty || ((doc = await FirebaseFirestore.instance.doc('user/$_login').get()).exists && doc[PASSWD] == passHash))
      _loginContinue(_login, context, false);
    else {
      _loginOrPassWrong = true;
      showProgress(false);
    }
  }

  void startTimer() => Timer(const Duration(seconds: 1), () {
        if (_timerStarted) {
          setState(() => --_remainingTimeToResend);
          if (_remainingTimeToResend == 0) _timerStarted = false;
          startTimer();
        }
      });

  onNext(BuildContext context) {
    if (_newLogin.isEmpty)
      setState(() => _newLoginEmpty = true);
    else
      register(context);
  }

  void openEmail() => platform.invokeMethod('startEmailApp', [_newLogin.split('@')[1]]);
}
