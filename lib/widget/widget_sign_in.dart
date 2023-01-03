// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hi/bloc/bloc_sign_in.dart';
import 'package:hi/util/util.dart';
import 'package:hi/widget/bar_with_progress.dart';
import 'package:hi/widget/widget_sign_up.dart';

import '../bloc/bloc_sign_in_email.dart';
import '../bloc/bloc_sign_up.dart';
import '../data/data_sign_in.dart';
import 'widget_sign_in_email.dart';

class SignInWidget extends StatelessWidget {
  static const _TAG = 'SignInWidget';
  final SignInBloc _signInBloc;

  const SignInWidget(this._signInBloc, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<SignInData>(
        initialData: const SignInData(),
        stream: _signInBloc.stream,
        builder: (context, snap) {
          hiLog(_TAG, 'data=>${snap.data}');
          final data = snap.data!;
          return SafeArea(
              child: Scaffold(
                  appBar: BarWithProgress(data.progress, null, title: const Text('hi')),
                  body: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            if (data.passLoginWrong)
                              Text(l10n?.pass_login_wrong ?? 'Login or password is wrong',
                                  style: const TextStyle(color: Colors.red)),
                            TextField(
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 20),
                                textInputAction: TextInputAction.next,
                                controller: _signInBloc.txtCtrLogin,
                                decoration: InputDecoration(
                                    hintText: l10n?.phone ?? 'phone number',
                                    prefixText: '+',
                                    prefixStyle: const TextStyle(color: Colors.black, fontSize: 20))),
                            if (data.loginInvalid)
                              Text(l10n?.phone_invalid ?? 'Invalid phone number', style: const TextStyle(color: Colors.red)),
                            TextField(
                              keyboardType: TextInputType.visiblePassword,
                              style: const TextStyle(fontSize: 20),
                              obscureText: data.obscure,
                              controller: _signInBloc.txtCtrPass,
                              decoration: InputDecoration(
                                  hintText: l10n?.passwd ?? 'password',
                                  suffixIcon: GestureDetector(
                                      onTap: () => _signInBloc.ctr.add(Command.OBSCURE),
                                      child: Icon(Icons.remove_red_eye_sharp, color: data.obscure ? Colors.red : Colors.grey))),
                            ),
                            ElevatedButton(
                                onPressed: () =>
                                    data.progress || _signInBloc.txtCtrLogin.text.isEmpty || _signInBloc.txtCtrPass.text.isEmpty
                                        ? null
                                        : _signInBloc.ctr.add(Command.SIGN_IN),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [const Icon(Icons.done), Text(l10n?.sign_in ?? 'Sign in')])),
                            ElevatedButton(
                                onPressed: () => data.progress
                                    ? null
                                    : Navigator.push(
                                        context, MaterialPageRoute(builder: (context) => EmailSignInWidget(EmailSignInBloc()))),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.email_outlined)),
                                 Expanded(child:  Text(l10n?.sign_in_email ?? 'Sign in with email',textAlign: TextAlign.center,))
                                ])),
                            ElevatedButton(
                                style: TextButton.styleFrom(backgroundColor: Colors.white),
                                onPressed: () => data.progress ? null : _signInBloc.ctr.add(Command.SIGN_IN_GOOGLE),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Image.asset('assets/icon/google.png', height: 24, width: 24)),
                                  Text(l10n?.sign_in_google ?? 'Sign in with Google', style: const TextStyle(color: Colors.grey))
                                ])),
                            ElevatedButton(
                                onPressed: () => _signUp(context, data),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [Text(l10n?.create ?? 'CREATE NEW ACCOUNT')])),
                            InkWell(
                                onTap: () => _signUp(context, data),
                                child: Text(l10n?.forgot ?? 'I forgot my password', style: const TextStyle(color: Colors.red)))
                          ])))));
        });
  }

  void _signUp(BuildContext context, SignInData data) {
    if (data.progress) return;
    final bloc = SignUpBloc();
    Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpWidget(bloc)))
        .whenComplete(() => bloc.ctr.add(CmdSignUp.CHECK_TIME));
  }
}

//       _newLogin = data[2];
//       if (data.length == 4) {
//         final times = data[3].split(':');
//         final timestamp = int.parse(times[0]);
//         final timeToResend = int.parse(times[1]);
//         final currTime = currentTimeInSec();
//         if (currTime - timestamp > timeToResend)
//           _remainingTimeToResend = 0;
//         else {
//           _remainingTimeToResend = timeToResend - currTime + timestamp;
//           _timerStarted = true;
//           startTimer();
//         }
//       }
//       setState(() {
//         verificationCode = data[1].split(':');
//         focusIndex = verificationCode.indexOf('') - 1;
//         _showVerificationForm = true;
//         showCodeSent = true;
//         currKey = UniqueKey();
//       });
//     } else

//   }
//
//   @override
//   Widget build(BuildContext context) {
//     ctx = context;
//     return Scaffold(
//         appBar: AppBar(
//             title: nameWidget,
//             bottom: _showProgress
//                 ? const PreferredSize(
//                     preferredSize: Size(double.infinity, 0), child: LinearProgressIndicator(backgroundColor: Colors.white))
//                 : null),
//         body: getChild(context));
//   }
//
//   Widget getChild(BuildContext context) {
//     final locs = AppLocalizations.of(context);
//     return _showLoading
//         ? const Center(child: CircularProgressIndicator())
//         : _showVerificationForm
//             ? Center(
//                 child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   if (showCodeSent)
//                     Column(mainAxisSize: MainAxisSize.min, children: [
//                       Text((locs?.sms ?? 'SMS is sent to') + ' +$_newLogin'),
//                       Row(mainAxisSize: MainAxisSize.min, children: [
//                         Text(locs?.you_can ?? 'You can'),
//                         InkWell(
//                             child: Text(' ' + (locs?.resend ?? 'resend') + ' ', style: const TextStyle(color: Colors.red)),
//                             onTap: () => register(context)),
//                         Text(locs?.after ?? 'after: '),
//                         Text('$_remainingTimeToResend secs')
//                       ])
//                     ]),
//                   Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: List.generate(6, (index) {
//                         var enabled = focusIndex == 6 || index == focusIndex;
//                         var c = verificationCode[index];
//                         return Row(children: [
//                           if (index > 0) sizedBox_w_4,
//                           SizedBox(
//                               width: 40,
//                               child: TextField(
//                                   key: (index == focusIndex) ? currKey : null,
//                                   enabled: enabled,
//                                   controller: TextEditingController(text: c)
//                                     ..selection = TextSelection(baseOffset: c.length, extentOffset: c.length),
//                                   onChanged: (txt) {
//                                     if (txt.length == 6)
//                                       setState(() => verificationCode = txt.split(''));
//                                     else if (txt.length == 2 && index < 5)
//                                       setState(() {
//                                         verificationCode[index + 1] = txt.characters.last;
//                                         focusIndex = index + 1;
//                                       });
//                                     else if (txt.isEmpty)
//                                       setState(() {
//                                         verificationCode[index] = '';
//                                         focusIndex = focusIndex > 0 ? index - 1 : focusIndex;
//                                       });
//                                     else
//                                       setState(() {
//                                         verificationCode[index] = txt[0];
//                                         focusIndex = index;
//                                       });
//                                   },
//                                   autofocus: showCodeSent && enabled,
//                                   showCursor: false,
//                                   style: const TextStyle(fontSize: 30),
//                                   textAlign: TextAlign.center,
//                                   keyboardType: TextInputType.number))
//                         ]);
//                       })),
//                   sizedBox_h_8,
//                   Row(mainAxisSize: MainAxisSize.min, children: [
//                     ElevatedButton(
//                         onPressed: verificationCode.any((e) => e.isEmpty) ? null : submit, child: Text(locs?.submit ?? 'SUBMIT')),
//                     sizedBox_w_8,
//                     ElevatedButton(
//                         onPressed: showCodeSent || showErr
//                             ? () {
//                                 SharedPreferences.getInstance().then((p) => p.remove(VERIFICATION_DATA));
//                                 setState(() {
//                                   _showVerificationForm = false;
//                                   showCodeSent = false;
//                                   focusIndex = 0;
//                                 });
//                                 for (int i = 0; i < verificationCode.length; i++) verificationCode[i] = '';
//                                 WidgetsBinding.instance.removeObserver(this);
//                               }
//                             : null,
//                         child: Text(
//                           locs?.cancel ?? 'CANCEL',
//                           overflow: TextOverflow.clip,
//                         ))
//                   ])
//                 ],
//               ))
//             : _signUp
//                 ? Center(
//                     child: ConstrainedBox(
//                         constraints: const BoxConstraints(maxWidth: 220),
//                         child: Column(mainAxisSize: MainAxisSize.min, children: [
//                           TextField(
//                             key: _registeringWithPhone ? phoneKey : emailKey,
//                             autofocus: true,
//                             onChanged: (String txt) {
//                               _newLogin = txt;
//                             },
//                             controller: TextEditingController(text: _newLogin)
//                               ..selection = TextSelection(baseOffset: _newLogin.length, extentOffset: _newLogin.length),
//                             decoration: InputDecoration(
//                                 prefixText: _registeringWithPhone ? '+' : '',
//                                 hintText: _registeringWithPhone
//                                     ? locs?.phone ?? 'Enter your phone number'
//                                     : locs?.email ?? 'Enter your email'),
//                             keyboardType: _registeringWithPhone ? TextInputType.number : TextInputType.emailAddress,
//                             inputFormatters: _registeringWithPhone ? [FilteringTextInputFormatter.digitsOnly] : null,
//                           ),
//                           if (_newLoginEmpty)
//                             Text(locs?.required ?? "This field is required",
//                                 style: const TextStyle(fontSize: 13, color: Colors.red))
//                           else if (_formatErr)
//                             Text(locs?.format_err ?? "Format is wrong", style: const TextStyle(fontSize: 13, color: Colors.red)),
//                           sizedBox_h_8,
//                           Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               ElevatedButton(
//                                   onPressed: !_timerStarted ? () => onNext(context) : null, child: Text(locs?.next ?? 'NEXT')),
//                               sizedBox_w_4,
//                               Expanded(
//                                   child: ElevatedButton(
//                                       onPressed: () => setState(() {
//                                             _signUp = false;
//                                             _showVerificationForm = false;
//                                             _login = '';
//                                             _newLogin = '';
//                                             _formatErr = false;
//                                           }),
//                                       child: FittedBox(
//                                         child: Text(locs?.cancel ?? 'CANCEL'),
//                                       )))
//                             ],
//                           ),
//                           if (_timerStarted)
//                             Text((locs?.can_send_after ?? 'You can send after:') + ' $_remainingTimeToResend secs')
//                         ])))
//                 : Center(
//                     child: SizedBox(
//                         width: 220,
//                         child: Column(mainAxisSize: MainAxisSize.min, children: [
//                           if (_loginOrPassWrong)
//                             Text(locs?.pass_login_wrong ?? 'Login or password is wrong',
//                                 style: const TextStyle(color: Colors.red))
//                           else if (_emailSignUpErr)
//                             Text(locs?.sign_in_problem ?? 'Could not sign in with email, try again please',
//                                 style: const TextStyle(fontSize: 13, color: Colors.red)),
//                           TextField(
//                               style: const TextStyle(fontSize: 20),
//                               onChanged: (String txt) {
//                                 if (txt.startsWith('+'))
//                                   setState(() => _login = txt.substring(1));
//                                 else
//                                   _login = txt;
//                               },
//                               textInputAction: TextInputAction.next,
//                               controller: TextEditingController(text: _login),
//                               decoration: InputDecoration(
//                                   hintText: locs?.phone ?? 'phone number',
//                                   prefixText: '+',
//                                   prefixStyle: const TextStyle(color: Colors.black, fontSize: 20))),
//                           if (_loginEmptyErr)
//                             Text(locs?.required ?? 'This field is required',
//                                 style: const TextStyle(fontSize: 13, color: Colors.red)),
//                           TextField(
//                             style: const TextStyle(fontSize: 20),
//                             obscureText: obscure,
//                             onChanged: (String txt) => _pass = txt,
//                             controller: TextEditingController(text: _pass)
//                               ..selection = TextSelection(baseOffset: _pass.length, extentOffset: _pass.length),
//                             decoration: InputDecoration(
//                                 hintText: locs?.passwd ?? 'password',
//                                 suffixIcon: GestureDetector(
//                                     onTap: () {
//                                       setState(() {
//                                         obscure = !obscure;
//                                       });
//                                     },
//                                     child: const Icon(Icons.remove_red_eye))),
//                             onSubmitted: (txt) => signIn(context),
//                           ),
//                           if (_passEmptyErr)
//                             Text(locs?.required ?? "This field is required",
//                                 style: const TextStyle(fontSize: 13, color: Colors.red)),
//                           sizedBox_h_8,
//                           HiBtn(() => signIn(context), locs?.sign_in ?? 'Sign in', const Icon(Icons.done),
//                               const Color.fromRGBO(0, 0, 0, 0.54)),
//                           HiBtn(
//                               () => googleSignIn(context),
//                               locs?.sign_in_google ?? 'Sign in with Google',
//                               const Image(
//                                   width: 18, height: 18, image: AssetImage('assets/icon/google.png'), fit: BoxFit.fitHeight),
//                               const Color.fromRGBO(0, 0, 0, 0.54)),
//                           HiBtn(() {
//                             setState(() {
//                               _signUp = true;
//                               _registeringWithPhone = false;
//                             });
//                           }, locs?.sign_in_email ?? 'Sign in with email', const Icon(Icons.email_outlined),
//                               const Color.fromRGBO(0, 0, 0, 0.54)),
//                           Padding(
//                               padding: const EdgeInsets.only(top: 4),
//                               child: HiBtn(
//                                   _register, locs?.create ?? 'CREATE NEW ACCOUNT', null, const Color.fromRGBO(0, 0, 0, 0.54))),
//                         ])));
//   }
//
//   void _register() {
//     if (!_showProgress)
//       setState(() {
//         _signUp = true;
//         _registeringWithPhone = true;
//       });
//   }
//
//   void register(context) {
//     if (_remainingTimeToResend > 0) return;
//     if (_registeringWithPhone)
//       phoneSignUp();
//     else if (RegExp(r'^([^&])+@([^&])+\.([^&])+$').hasMatch(_newLogin)) {
//       setState(() {
//         _formatErr = false;
//         _newLoginEmpty = false;
//       });
//       emailSignUp();
//     } else
//       setState(() {
//         _formatErr = true;
//         _newLoginEmpty = false;
//       });
//   }
//
//   emailSignUp() async {
//     if (_showProgress) return;
//     final locs = AppLocalizations.of(ctx);
//     if (RegExp(r'(mail.ru|bk.ru|list.ru|internet.ru|inbox.ru)').hasMatch(_newLogin))
//       return showSnack(locs?.mail_ru_problem ?? 'Email sign in does not work with mail.ru, try other email please', 5, ctx);
//     showProgress(true);

//         content: Row(children: [
//           Expanded(child: Text(locs?.email_sent(_newLogin) ?? 'Email is sent to $_newLogin.  Check SPAM also.')),
//           TextButton(onPressed: openEmail, child: Text(locs?.open ?? 'OPEN'))
//         ]),
//         duration: const Duration(seconds: 11)));
//   }
//
//   void showProgress(bool b) => setState(() => _showProgress = b);
//
//   Future<String?> getId() => platform.invokeMethod('getPackageName');
//
//   phoneSignUp() async {
//     final locs = AppLocalizations.of(ctx);
//     if (_newLogin.length < 4 || _newLogin.length > 15) {
//       _newLoginEmpty = false;
//       if (!_formatErr) setState(() => _formatErr = true);
//     } else if (widget._connectedToInet) {
//       showProgress(true);
//       await auth.verifyPhoneNumber(
//           phoneNumber: '+' + _newLogin,
//           verificationCompleted: (PhoneAuthCredential cred) {
//             hiLog(TAG, 'verification completed, cred=>$cred');
//             setState(() {
//               verificationCode = cred.smsCode!.split('');
//               _showProgress = false;
//             });
//             submit();
//           },
//           verificationFailed: (e) {
//             hiLog(TAG, 'failed=>$e, code=>${e.code}');
//             if (e.code == "too-many-requests")
//               showSnack(locs?.ip_blocked ?? 'Your IP has been temporarily blocked. Try again later please', 4, ctx);
//             else if (e.code == 'invalid-phone-number') {
//               showSnack(locs?.phone_invalid ?? 'Invalid phone number', 4, ctx);
//               setState(() => _showVerificationForm = false);
//             } else if (e.code == 'web-internal-error')
//               showSnack(locs?.internal_err ?? 'There was an internal error, try again later please', 4, context);
//             else if (e.code == 'app-not-authorized')
//               showSnack(locs?.phone_unavailable ?? 'Phone sign up is currently not working, try other method please', 4, ctx);
//             showErr = true;
//             showProgress(false);
//           },
//           codeSent: (id, token) {
//             showProgress(false);
//             showCodeSent = true;
//             _timerStarted = true;
//             _remainingTimeToResend = 120;
//             currKey = UniqueKey();
//             startTimer();
//             _verificationId = id;
//             WidgetsBinding.instance.addObserver(this);
//           },
//           codeAutoRetrievalTimeout: (id) {});
//       setState(() {
//         _showVerificationForm = true;
//         _formatErr = false;
//       });
//     } else
//       showSnack(locs?.no_inet ?? 'No internet', 1, ctx);
//   }
//
//   submit() async {
//     if (_showProgress) return;
//     showProgress(true);
//     SharedPreferences.getInstance().then((p) => p.remove(VERIFICATION_DATA));
//     PhoneAuthCredential credential =
//         PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: verificationCode.join());
//     auth.signInWithCredential(credential).then((value) {
//       _timerStarted = false;
//       _login = _newLogin;
//       widget.onSetPassd(_login);
//     }, onError: (e) {
//       if (e is FirebaseAuthException && e.code == 'invalid-verification-code') {
//         showSnack(AppLocalizations.of(ctx)?.sms_invalid ?? 'Invalid SMS code', 2, ctx);
//         showProgress(false);
//       }
//     });
//     WidgetsBinding.instance.removeObserver(this);
//   }
//

//
//   _loginContinue(String login, BuildContext context, fromDLink) async {
//     if (fromDLink)
//       setState(() => _showLoading = true);
//     else
//       showProgress(true);
//     final sp = await SharedPreferences.getInstance();
//     final db = await openDatabase(join(await getDatabasesPath(), DB_NAME), version: DB_VERSION_1);
//     sp.setString(LOGIN, login);
//     sp.setBool(IS_SIGNED_IN, true);
//     final List<Map<String, Object?>> res;
//     final data =
//         (res = await db.query(TABLE_USER, columns: [BLOCK_PERIOD, BLOCK_TIME], where: '$LOGIN=?', whereArgs: [login])).isNotEmpty
//             ? res.first
//             : {};
//     final blockPeriod = data[BLOCK_PERIOD] ?? BLOCK_NO;
//     final blockTime = data[BLOCK_TIME];
//     DateTime unblockTime;
//     final DocumentSnapshot doc;
//     try {
//       if (blockPeriod != BLOCK_NO &&
//           DateTime.now().isBefore(
//               unblockTime = DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod)))))
//         return widget.onBlocked(login, unblockTime, blockPeriod);
//       else if (blockPeriod != BLOCK_NO &&
//           DateTime.now()
//               .isAfter(DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod))))) {
//         db.update(TABLE_USER, {BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: blockPeriod}, where: '$LOGIN=?', whereArgs: [login]);
//         FirebaseFirestore.instance.doc('user/$login').set(
//             {BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: blockPeriod, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0)},
//             SetOptions(merge: true));
//       } else if (!(doc = await FirebaseFirestore.instance.doc('user/$login').get()).exists) {
//         FirebaseFirestore.instance
//             .doc('user/$login')
//             .set({BLOCK_PERIOD: BLOCK_NO, BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0), LAST_BLOCK_PERIOD: BLOCK_NO});
//         db.insert(TABLE_USER, {LOGIN: login});
//       } else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
//           DateTime.now().isBefore(
//               unblockTime = (doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD]))))) {
//         sp.setInt(BLOCK_PERIOD, doc[BLOCK_PERIOD]);
//         final millis = (doc[BLOCK_TIME] as Timestamp).millisecondsSinceEpoch;
//         sp.setInt(BLOCK_TIME, millis);
//         db.insert(TABLE_USER,
//             {LOGIN: login, BLOCK_PERIOD: doc[BLOCK_PERIOD], BLOCK_TIME: millis, LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD]});
//         return widget.onBlocked(login, unblockTime, doc[BLOCK_PERIOD]);
//       } else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
//           DateTime.now().isAfter((doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD]))))) {
//         FirebaseFirestore.instance
//             .doc('user/$login')
//             .set({BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD]}, SetOptions(merge: true));
//         db.insert(TABLE_USER, {LOGIN: login, BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD]});
//       } else if (data.isEmpty) db.insert(TABLE_USER, {LOGIN: login});
//     } catch (e) {
//       if (mounted) {
//         showSnack(AppLocalizations.of(context)?.err_conn ?? 'Connection error, try again please', 2, context);
//         setState(() => _showProgress = false);
//       }
//       return;
//     }
//     updateDBWithBlockedUsersAndReporters(db, login);
//     widget.onSuccess(login);
//   }
//
//   signIn(BuildContext context) async {
//     if (_showProgress) return;
//     if (!RegExp(r'(\d+$)').hasMatch(_login)) {
//       setState(() {
//         _loginOrPassWrong = true;
//         _passEmptyErr = false;
//       });
//       return;
//     }
//     showProgress(true);
//     final db = await openDatabase(join(await getDatabasesPath(), DB_NAME), version: DB_VERSION_1);
//     final passHash = md5.convert(utf8.encode(_pass)).toString();
//     final res =
//         await db.query(TABLE_USER, columns: [LOGIN, PASSWD], where: '$LOGIN=? AND $PASSWD=?', whereArgs: [_login, passHash]);
//     final DocumentSnapshot<Map<String, dynamic>> doc;
//     if (res.isNotEmpty || ((doc = await FirebaseFirestore.instance.doc('user/$_login').get()).exists && doc[PASSWD] == passHash))
//       _loginContinue(_login, context, false);
//     else {
//       _loginOrPassWrong = true;
//       showProgress(false);
//     }
//   }
//
//   void startTimer() => Timer(const Duration(seconds: 1), () {
//         if (_timerStarted) {
//           setState(() => --_remainingTimeToResend);
//           if (_remainingTimeToResend == 0) _timerStarted = false;
//           startTimer();
//         }
//       });
//
//   onNext(BuildContext context) {
//     if (_newLogin.isEmpty)
//       setState(() => _newLoginEmpty = true);
//     else
//       register(context);
//   }
//
