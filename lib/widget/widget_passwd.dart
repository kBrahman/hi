// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hi/widget/widget_main.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../util/util.dart';

class PasswdWidget extends StatefulWidget {
  String _login;
  final Function(UIState state) _onCancel;
  final bool _connectedToInet;
  final Function(String login) _onSuccess;
  final Function(String, DateTime, int) _onBlocked;

  PasswdWidget(this._onCancel, this._onSuccess, this._onBlocked, this._login, this._connectedToInet, {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PasswdState();
  }
}

class _PasswdState extends State<PasswdWidget> {
  static const TAG = '_SetPasswdState';
  var txtErr = false;
  String pass = '';
  String _rePass = '';
  bool _obscure = true;
  var _showProgress = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text('hi'),
            actions: [IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: const Icon(Icons.remove_red_eye))],
            bottom: _showProgress
                ? const PreferredSize(
                    preferredSize: Size(double.infinity, 0), child: LinearProgressIndicator(backgroundColor: Colors.white))
                : null),
        body: getChild(context));
  }

  Center getChild(BuildContext context) {
    return Center(
        child: SizedBox(
            width: 220,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(bottom: 6), child: Text('Create a password', style: TextStyle(fontSize: 20))),
                Text('1. Password must contain lowercase letters',
                    style: TextStyle(
                        fontSize: 11, color: pass.contains(RegExp(r'\p{Ll}', unicode: true)) ? Colors.green : Colors.red)),
                Text('2. Password must contain uppercase letters',
                    style: TextStyle(
                        fontSize: 11, color: pass.contains(RegExp(r'\p{Lu}', unicode: true)) ? Colors.green : Colors.red)),
                Text('3. Password must contain numbers',
                    style: TextStyle(fontSize: 11, color: pass.contains(RegExp(r'\d')) ? Colors.green : Colors.red)),
                Text('4. Password minimum length is 8',
                    style: TextStyle(fontSize: 11, color: pass.length > 7 ? Colors.green : Colors.red)),
                Text('5. Passwords must match',
                    style: TextStyle(fontSize: 11, color: pass.isNotEmpty && pass == _rePass ? Colors.green : Colors.red))
              ]),
              TextField(
                autofocus: true,
                enableInteractiveSelection: false,
                obscureText: _obscure,
                onChanged: (String txt) {
                  setState(() {
                    pass = txt;
                  });
                },
                style: const TextStyle(fontSize: 20),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'password',),
              ),
              TextField(
                enableInteractiveSelection: false,
                obscureText: _obscure,
                style: const TextStyle(fontSize: 20),
                onChanged: (String txt) {
                  if (txt.isNotEmpty)
                    setState(() {
                      _rePass = txt;
                    });
                },
                decoration: const InputDecoration(hintText: 'retype password'),
                onSubmitted: (v) {
                  proceed(context);
                },
              ),
              if (txtErr) const Text("This field is required", style: TextStyle(fontSize: 13, color: Colors.red)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(onPressed: () => proceed(context), child: const Text('NEXT')),
                  sizedBox_w_4,
                  ElevatedButton(
                      onPressed: () {
                        if (!_showProgress) widget._onCancel(UIState.SIGN_IN_UP);
                      },
                      child: const Text('CANCEL'))
                ],
              )
            ])));
  }

  proceed(context) async {
    if (_showProgress ||
        !(pass.contains(RegExp(r'\p{Ll}', unicode: true))) ||
        !pass.contains(RegExp(r'\p{Lu}', unicode: true)) ||
        !pass.contains(RegExp(r'\d')) ||
        pass.length < 8 ||
        !pass.isNotEmpty ||
        pass != _rePass) return;
    if (widget._connectedToInet) {
      showProgress(true);
      final List<Map<String, Object?>> res;
      final db = await openDatabase(join(await getDatabasesPath(), DB_NAME), version: DB_VERSION_1);
      final sp = await SharedPreferences.getInstance();
      final data = (res =
                  await db.query(TABLE_USER, columns: [BLOCK_PERIOD, BLOCK_TIME], where: '$LOGIN=?', whereArgs: [widget._login]))
              .isNotEmpty
          ? res.first
          : {};
      final blockPeriod = data[BLOCK_PERIOD] ?? BLOCK_NO;
      final blockTime = data[BLOCK_TIME];
      DateTime unblockTime;
      final DocumentSnapshot doc;
      final passHash = md5.convert(utf8.encode(pass)).toString();
      try {
        if (blockPeriod != BLOCK_NO &&
            DateTime.now().isBefore(
                unblockTime = DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod)))))
          return widget._onBlocked(widget._login, unblockTime, blockPeriod);
        else if (blockPeriod != BLOCK_NO &&
            DateTime.now()
                .isAfter(DateTime.fromMillisecondsSinceEpoch(blockTime).add(Duration(minutes: getMinutes(blockPeriod))))) {
          db.update(TABLE_USER, {BLOCK_PERIOD: BLOCK_NO, LAST_BLOCK_PERIOD: blockPeriod, PASSWD: passHash},
              where: '$LOGIN=?', whereArgs: [widget._login]);
          FirebaseFirestore.instance.doc('user/${widget._login}').set({
            BLOCK_PERIOD: BLOCK_NO,
            LAST_BLOCK_PERIOD: blockPeriod,
            PASSWD: passHash,
            BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0)
          }, SetOptions(merge: true));
        } else if (!(doc = await FirebaseFirestore.instance.doc('user/${widget._login}').get()).exists) {
          FirebaseFirestore.instance.doc('user/${widget._login}').set({
            BLOCK_PERIOD: BLOCK_NO,
            BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0),
            LAST_BLOCK_PERIOD: BLOCK_NO,
            PASSWD: passHash
          });
          db.insert(TABLE_USER, {LOGIN: widget._login, PASSWD: passHash});
        } else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
            DateTime.now().isBefore(
                unblockTime = (doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD]))))) {
          sp.setInt(BLOCK_PERIOD, doc[BLOCK_PERIOD]);
          final millis = (doc[BLOCK_TIME] as Timestamp).millisecondsSinceEpoch;
          sp.setInt(BLOCK_TIME, millis);
          db.insert(TABLE_USER, {
            LOGIN: widget._login,
            BLOCK_PERIOD: doc[BLOCK_PERIOD],
            BLOCK_TIME: millis,
            LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD],
            PASSWD: doc[PASSWD]
          });
          hiLog(TAG, 'second on blocked');
          return widget._onBlocked(widget._login, unblockTime, doc[BLOCK_PERIOD]);
        } else if (doc[BLOCK_PERIOD] != BLOCK_NO &&
            DateTime.now()
                .isAfter((doc[BLOCK_TIME] as Timestamp).toDate().add(Duration(minutes: getMinutes(doc[BLOCK_PERIOD]))))) {
          FirebaseFirestore.instance.doc('user/${widget._login}').set({
            BLOCK_PERIOD: BLOCK_NO,
            LAST_BLOCK_PERIOD: blockPeriod,
            PASSWD: passHash,
            BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0)
          }, SetOptions(merge: true));
          db.insert(TABLE_USER, {
            LOGIN: widget._login,
            BLOCK_PERIOD: BLOCK_NO,
            BLOCK_TIME: Timestamp.fromMillisecondsSinceEpoch(0),
            LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD],
            PASSWD: passHash
          });
        } else if (data.isEmpty) db.insert(TABLE_USER, {LOGIN: widget._login, PASSWD: passHash});
      } catch (e) {
        hiLog(TAG, 'e=>$e');
        showSnack(AppLocalizations.of(context)?.err_conn ?? 'Connection error, try again please', 2, context);
        setState(() => _showProgress = false);
      }
      sp.setBool(SIGNED_IN, true);
      sp.setString(LOGIN, widget._login);
      updateDBWithBlockedUsersAndReporters(db, widget._login);
      widget._onSuccess(widget._login);
    } else
      showSnack('No internet', 1, context);
  }

  void showProgress(bool b) {
    setState(() {
      _showProgress = b;
    });
  }
}
