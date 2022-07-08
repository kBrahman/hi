// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:sqflite/sqflite.dart';

import '../util/util.dart';

class SignInOrRegWidget extends StatefulWidget {
  final Function(String) onSuccess;
  final bool _connectedToInet;
  final Function(String, DateTime, int) onBlocked;

  const SignInOrRegWidget(this.onSuccess, this.onBlocked, this._connectedToInet, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SignInOrUpState();
}

class _SignInOrUpState extends State<SignInOrRegWidget> with WidgetsBindingObserver {
  static const TAG = 'SignInState';

  static const sizedBox_h_4 = SizedBox(height: 4);

  var txtErr = false;
  String _login = '';
  bool signUp = false;
  var showVerificationForm = false;
  var _newLogin = '';
  var _newLoginEmpty = false;
  var _formatErr = false;
  var verificationCode = List.filled(6, '');
  var registeringWithPhone = true;
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
  String pass = '';
  var _showProgress = false;
  var loginOrPassWrong = false;
  late Database db;

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    hiLog(TAG, 'didChangeAppLifecycleState state=>$state');
    switch (state) {
      case AppLifecycleState.inactive:
        {
          hiLog(TAG, 'saving state verification code=>$verificationCode');
          var p = await SharedPreferences.getInstance();
          var data = [_verificationId, verificationCode.join(':'), _newLogin];
          if (_remainingTimeToResend > 0) {
            final currTime = currentTimeInSec();
            data.add('$currTime:$_remainingTimeToResend');
          }
          var res = await p.setStringList(VERIFICATION_DATA, data);
          hiLog(TAG, 'finished saving state, result ok=>$res');
        }
    }
  }

  int currentTimeInSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  @override
  void initState() {
    hiLog(TAG, 'init state');
    SharedPreferences.getInstance().then((p) {
      if (p.containsKey(VERIFICATION_DATA)) {
        final data = p.getStringList(VERIFICATION_DATA)!;
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
          showVerificationForm = true;
          showCodeSent = true;
          currKey = UniqueKey();
        });
      }
    });
    auth.setLanguageCode(Platform.localeName.substring(0, 2));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: nameWidget,
            bottom: _showProgress
                ? const PreferredSize(
                    preferredSize: Size(double.infinity, 0),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white,
                    ))
                : null),
        body: getChild(context));
  }

  Center getChild(BuildContext context) {
    return showVerificationForm
        ? Center(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCodeSent)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('An SMS is sent to $_newLogin'),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('You can '),
                    InkWell(child: const Text('resend', style: TextStyle(color: Colors.red)), onTap: register),
                    const Text(' after: '),
                    Text('$_remainingTimeToResend secs')
                  ]),
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
                                hiLog(TAG, 'on changed=>$txt');
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
                  ElevatedButton(onPressed: verificationCode.any((e) => e.isEmpty) ? null : submit, child: const Text('SUBMIT')),
                  sizedBox_w_8,
                  ElevatedButton(
                      onPressed: showCodeSent || showErr
                          ? () {
                              SharedPreferences.getInstance().then((p) => p.remove(VERIFICATION_DATA));
                              setState(() {
                                showVerificationForm = false;
                                showCodeSent = false;
                                focusIndex = 0;
                              });
                              for (int i = 0; i < verificationCode.length; i++) verificationCode[i] = '';
                              WidgetsBinding.instance.removeObserver(this);
                            }
                          : null,
                      child: const Text('CANCEL'))
                ],
              )
            ],
          ))
        : signUp
            ? Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Use:'),
                        sizedBox_w_8,
                        RadioText(
                            'Phone',
                            () => setState(() {
                                  registeringWithPhone = true;
                                }),
                            registeringWithPhone),
                        RadioText(
                            'Email',
                            () => setState(() {
                                  registeringWithPhone = false;
                                }),
                            !registeringWithPhone),
                      ]),
                      TextField(
                        key: registeringWithPhone ? phoneKey : emailKey,
                        autofocus: true,
                        onChanged: (String txt) {
                          _newLogin = txt;
                        },
                        controller: TextEditingController(text: _newLogin)
                          ..selection = TextSelection(baseOffset: _newLogin.length, extentOffset: _newLogin.length),
                        decoration: InputDecoration(
                            prefixText: registeringWithPhone ? '+' : '',
                            hintText: registeringWithPhone ? 'Enter your phone number' : 'Enter your email'),
                        keyboardType: registeringWithPhone ? TextInputType.number : TextInputType.emailAddress,
                        inputFormatters: registeringWithPhone ? [FilteringTextInputFormatter.digitsOnly] : null,
                      ),
                      if (_newLoginEmpty) const Text("This field is required", style: TextStyle(fontSize: 13, color: Colors.red)),
                      if (_formatErr) const Text("Format is wrong", style: TextStyle(fontSize: 13, color: Colors.red)),
                      sizedBox_h_8,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(onPressed: !_timerStarted ? onNext : null, child: const Text('NEXT')),
                          sizedBox_w_4,
                          ElevatedButton(
                              onPressed: () => setState(() {
                                    signUp = false;
                                    showVerificationForm = false;
                                  }),
                              child: const Text('CANCEL'))
                        ],
                      ),
                      if (_timerStarted) Text('You can send after: $_remainingTimeToResend secs')
                    ])))
            : Center(
                child: SizedBox(
                    width: 220,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // if (loginOrPassWrong) const Text('Login or password is wrong', style: TextStyle(color: Colors.red)),
                      // TextField(
                      //   onChanged: (String txt) => _login = txt,
                      //   textInputAction: TextInputAction.next,
                      //   decoration: const InputDecoration(hintText: 'phone or email'),
                      // ),
                      // TextField(
                      //   obscureText: obscure,
                      //   onChanged: (String txt) => pass = txt,
                      //   decoration: InputDecoration(
                      //       hintText: 'password',
                      //       suffixIcon: GestureDetector(
                      //           onTap: () {
                      //             setState(() {
                      //               obscure = !obscure;
                      //             });
                      //           },
                      //           child: const Icon(Icons.remove_red_eye))),
                      //   onSubmitted: (txt) => signIn(),
                      // ),
                      // if (txtErr) const Text("This field is required", style: TextStyle(fontSize: 13, color: Colors.red)),
                      // sizedBox_h_8,
                      // HiBtn(
                      //   () => _login.isEmpty ? setState(() => txtErr = true) : signIn(),
                      //   'Sign in',
                      //   Icons.done,
                      //   const Color.fromRGBO(0, 0, 0, 0.54),
                      // ),
                      SignInButton(Buttons.Google,
                          text: AppLocalizations.of(context)?.sign_in_google, onPressed: () => googleSignIn(context)),
                      // SignInButton(Buttons.Apple, onPressed: appleSignIn),
                      // sizedBox_h_8,
                      // HiBtn(() {
                      //   if (!_showProgress) setState(() => signUp = true);
                      // }, 'CREATE NEW ACCOUNT', null, Colors.black),
                      // sizedBox_h_4,
                      // InkWell(
                      //   child: const Text(
                      //     'I forgot my password',
                      //     style: TextStyle(color: Colors.red),
                      //   ),
                      //   onTap: () {},
                      // )
                    ])));
  }

  void register() {
    if (_remainingTimeToResend > 0) return;
    if (registeringWithPhone)
      phoneSignUp();
    else if (RegExp(r'^([^&])+@([^&])+\.([^&])+$').hasMatch(_newLogin))
      emailSignUp();
    else
      setState(() {
        _formatErr = true;
        _newLoginEmpty = false;
      });
  }

  emailSignUp() async {
    if (_showProgress) return;
    showProgress(true);
    try {
      var instance = FirebaseAuth.instance;
      var id = await getId();
      hiLog(TAG, 'id=>$id, type=>${id.runtimeType}');
      final actionCodeSettings = ActionCodeSettings(
          dynamicLinkDomain: 'proximityapp.page.link',
          url: 'https://www.proximityapp.page.link/signIn?id=' + _newLogin,
          androidPackageName: id,
          androidInstallApp: true,
          iOSBundleId: id,
          handleCodeInApp: true,
          androidMinimumVersion: '1');
      await instance.sendSignInLinkToEmail(email: _newLogin, actionCodeSettings: actionCodeSettings);
      hiLog(TAG, 'email sent');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        hiLog(TAG, 'The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        hiLog(TAG, 'The account already exists for that email.');
      }
    } on Error catch (err) {
      hiLog(TAG, 'err=>$err');
    } catch (e) {
      hiLog(TAG, 'exception=>${e.toString()}');
    } finally {
      showProgress(false);
    }
  }

  void showProgress(bool b) {
    setState(() {
      _showProgress = b;
    });
  }

  Future<String?> getId() => platform.invokeMethod('getPackageName');

  phoneSignUp() async {
    hiLog(TAG, 'phone sign up');
    if (_newLogin.length < 11 || _newLogin.length > 14) {
      _newLoginEmpty = false;
      if (!_formatErr) setState(() => _formatErr = true);
      hiLog(TAG, 'new login=>$_newLogin');
    } else if (widget._connectedToInet) {
      hiLog(TAG, 'number=>$_newLogin');
      showProgress(true);
      await auth.verifyPhoneNumber(
          phoneNumber: '+' + _newLogin,
          verificationCompleted: (cred) {
            hiLog(TAG, 'verification completed, cred=>$cred');
            setState(() {
              verificationCode = cred.smsCode!.split('');
            });
            submit();
          },
          verificationFailed: (e) {
            hiLog(TAG, 'failed=>$e, code=>${e.code}');
            if (e.code == "too-many-requests")
              showSnack("This number has been temporarily blocked. Try again later please", 4, context);
            else if (e.code == 'invalid-phone-number')
              showSnack("Invalid phone number", 4, context);
            else if (e.code == 'web-internal-error') showSnack("There was an internal error, try again later please", 4, context);
            setState(() {
              showErr = true;
            });
            showProgress(false);
          },
          codeSent: (id, token) {
            hiLog(TAG, 'sent id=>$id; token=>$token');
            showProgress(false);
            showCodeSent = true;
            _timerStarted = true;
            _remainingTimeToResend = 60;
            currKey = UniqueKey();
            startTimer();
            _verificationId = id;
            WidgetsBinding.instance.addObserver(this);
          },
          codeAutoRetrievalTimeout: (id) {
            hiLog(TAG, 'time out');
          });
      setState(() {
        showVerificationForm = true;
        _formatErr = false;
      });
    } else
      showSnack('No internet', 1, context);
  }

  submit() async {
    if (_showProgress) return;
    showProgress(true);
    SharedPreferences.getInstance().then((p) => p.remove(VERIFICATION_DATA));
    PhoneAuthCredential credential =
        PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: verificationCode.join());
    auth.signInWithCredential(credential).then((value) {
      _timerStarted = false;
    }, onError: (e) {
      hiLog(TAG, e.code);
      if (e is FirebaseAuthException && e.code == 'invalid-verification-code') {
        hiLog(TAG, 'invalid sms');
        showSnack('Invalid SMS code', 2, context);
        showProgress(false);
      }
    });
    WidgetsBinding.instance.removeObserver(this);
  }

  appleSignIn() async {
    if (_showProgress) return;
    if (widget._connectedToInet) {
      try {
        final credential = await SignInWithApple.getAppleIDCredential(
            scopes: [],
            webAuthenticationOptions: WebAuthenticationOptions(
                clientId: 'dev.tok.proximity.service', redirectUri: Uri.parse('https://proximityapp.page.link/app')));
        var login = credential.userIdentifier;
        if (login == null) {
          showSnack('Could not sign in with Apple. Try other  method please', 4, context);
        } else {
          // loginContinue(login);
          hiLog(TAG, 'after login continue');
        }
      } on SignInWithAppleAuthorizationException catch (e) {
        hiLog(TAG, 'sign in er=>$e');
      }
    } else
      showSnack('No internet', 1, context);
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
      if (login != null)
        try {
          loginContinue(login);
        } catch (e) {
          hiLog(TAG, 'e=>$e');
          showSnack(AppLocalizations.of(context)?.err_conn ?? 'Connection error, try again please', 2, context);
          setState(() => _showProgress = false);
        }
      hiLog(TAG, 'after login continue, login=>$login');
    } else
      showSnack('No internet', 1, context);
  }

  loginContinue(String login) async {
    showProgress(true);
    final sp = await SharedPreferences.getInstance();
    final db = await openDatabase(join(await getDatabasesPath(), DB_NAME), readOnly: true, version: DB_VERSION_1);
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
    if (blockPeriod != BLOCK_NO &&
        DateTime.now().isBefore(
            unblockTime = DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod)))))
      return widget.onBlocked(login, unblockTime, blockPeriod);
    else if (blockPeriod != BLOCK_NO &&
        DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod))))) {
      db.update(TABLE_USER, {BLOCK_PERIOD: BLOCK_NO}, where: '$LOGIN=?', whereArgs: [login]);
      FirebaseFirestore.instance
          .doc('user/$login')
          .set({BLOCK_PERIOD: BLOCK_NO, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0)}, SetOptions(merge: true));
    } else if (!(doc = await FirebaseFirestore.instance.doc('user/$login').get()).exists)
      FirebaseFirestore.instance
          .doc('user/$login')
          .set({BLOCK_PERIOD: BLOCK_NO, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0), LAST_BLOCK_PERIOD: BLOCK_NO});
    else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
        DateTime.now().isBefore(
            unblockTime = (doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD]))))) {
      sp.setInt(BLOCK_PERIOD, doc[BLOCK_PERIOD]);
      final millis = (doc[BLOCK_TIME] as Timestamp).millisecondsSinceEpoch;
      sp.setInt(BLOCK_TIME, millis);
      db.insert(
          TABLE_USER, {LOGIN: login, BLOCK_PERIOD: doc[BLOCK_PERIOD], BLOCK_TIME: millis, LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD]});
      return widget.onBlocked(login, unblockTime, doc[BLOCK_PERIOD]);
    } else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
        DateTime.now()
            .isAfter(unblockTime = (doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD])))))
      FirebaseFirestore.instance
          .doc('user/$login')
          .set({BLOCK_PERIOD: BLOCK_NO, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0)}, SetOptions(merge: true));
    db.insert(TABLE_USER, {LOGIN: login});
    _updateDBWithBlockedUsersAndReporters(db, login);
    widget.onSuccess(login);
  }

  signIn() async {
    if (_showProgress) return;
    showProgress(true);
    final login = _login.startsWith('+') ? _login.substring(1) : _login;

    final password = md5.convert(utf8.encode(pass)).toString();

    var res = await db.query(TABLE_USER,
        columns: [LOGIN, COLUMN_PASSWD], where: '$LOGIN=? AND $COLUMN_PASSWD=?', whereArgs: [login, password]);
    final sp = await SharedPreferences.getInstance();
    if (res.isNotEmpty) {
      sp.setBool(SIGNED_IN, true);
      widget.onSuccess(login);
    } else {
      var doc = FirebaseFirestore.instance.doc('user/$login');
      final d = await doc.get();
      if (d.exists && d[COLUMN_PASSWD] == password) {
        sp.setBool(SIGNED_IN, true);
        db.insert(TABLE_USER, {LOGIN: login, COLUMN_PASSWD: password}, conflictAlgorithm: ConflictAlgorithm.replace);
        widget.onSuccess(login);
      } else {
        loginOrPassWrong = true;
        showProgress(false);
      }
    }
  }

  void startTimer() => Timer(const Duration(seconds: 1), () {
        if (_timerStarted) {
          setState(() => --_remainingTimeToResend);
          if (_remainingTimeToResend == 0) _timerStarted = false;
          startTimer();
        }
      });

  onNext() {
    if (_newLogin.isEmpty)
      setState(() => _newLoginEmpty = true);
    else
      register();
  }

  Future<void> _updateDBWithBlockedUsersAndReporters(Database db, String login) async {
    final blockedUsers = (await FirebaseFirestore.instance.collection('user/$login/$BLOCKED_USER').get()).docs;
    for (final u in blockedUsers) db.insert(BLOCKED_USER, {BLOCKED_LOGIN: u.id, NAME: u[NAME], LOGIN: login});
    final reporters = (await FirebaseFirestore.instance.collection('user/$login/$REPORT').get()).docs;
    for (final u in reporters) db.insert(REPORT, {REPORTER_LOGIN: u.id, LOGIN: login});
  }
}

class RadioText extends StatelessWidget {
  final bool registeringWithPhone;
  final VoidCallback onSelected;
  final String title;

  const RadioText(this.title, this.onSelected, this.registeringWithPhone, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Radio(
          visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity),
          groupValue: 0,
          value: registeringWithPhone ? 0 : 1,
          onChanged: (v) => onSelected(),
        ),
        Text(title)
      ],
    );
  }
}
