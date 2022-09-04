// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../util/util.dart';

class ProfileWidget extends StatefulWidget {
  final Function(String) _onStart;
  final VoidCallback onExit;
  final SharedPreferences sp;

  const ProfileWidget(this._onStart, this.onExit, this.sp, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileWidget> with WidgetsBindingObserver {
  static const TAG = '_ProfileState';
  var _blockedUsers = <Map<String, Object?>>[];
  var _name = '';
  var _login = '';
  late Database _db;
  var _showNameEmpty = false;

  @override
  void initState() {
    super.initState();
    _getCreds(widget.sp);
  }

  @override
  Widget build(BuildContext context) {
    const edgeInsetsTop16 = EdgeInsets.only(top: 16);
    final locs = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: nameWidget, actions: [IconButton(onPressed: widget.onExit, icon: const Icon(Icons.exit_to_app))]),
        body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((locs?.logged_in_as ?? 'Logged in as:') + ' $_login', style: const TextStyle(color: Colors.grey)),
              Column(children: [
                Row(children: [
                  Text((locs?.name ?? 'Your name') + ':', style: bold20),
                  Expanded(
                      child: Padding(
                          padding: edgeInsetsLR8,
                          child: TextField(
                              style: const TextStyle(fontSize: 20),
                              onChanged: (v) {
                                _name = v;
                                if (_showNameEmpty) setState(() => _showNameEmpty = false);
                              },
                              controller: TextEditingController(text: _name))))
                ]),
                if (_showNameEmpty)
                  Text(locs?.name_enter ?? 'Enter your name please', style: const TextStyle(fontSize: 12, color: Colors.red)),
              ]),
              Padding(padding: edgeInsetsTop16, child: Text(locs?.blocked_users ?? 'Blocked users:', style: bold20)),
              Expanded(
                  child: ListView(
                      padding: const EdgeInsets.only(top: 4),
                      children: _blockedUsers
                          .map((m) => Dismissible(
                              onDismissed: (d) => _unblock(m),
                              key: ValueKey(m[BLOCKED_LOGIN]),
                              child: Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(m[NAME] as String, style: const TextStyle(fontSize: 30))))))
                          .toList())),
              Padding(
                  padding: edgeInsetsTop16,
                  child: Center(
                      child: ElevatedButton(
                          onPressed: () async {
                            if (_name.isEmpty)
                              setState(() => _showNameEmpty = true);
                            else {
                              await [Permission.camera, Permission.microphone].request().then((statuses) {
                                final denied = Map.from(statuses)
                                  ..removeWhere((key, value) => value != PermissionStatus.permanentlyDenied);
                                if (denied.isNotEmpty)
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Row(children: [
                                        Expanded(
                                            child: Text(locs?.open_settings ??
                                                'Please go to settings and give acces to your camera and microphone')),
                                        TextButton(onPressed: openAppSettings, child: Text(locs?.settings ?? 'SETTINGS'))
                                      ]),
                                      duration: const Duration(seconds: 8)));
                                else
                                  statuses.values.any((e) => !e.isGranted)
                                      ? showSnack(locs?.give_access??'Please give access to your camera and microphone!', 2, context)
                                      : widget._onStart(_name);
                              });
                              widget.sp.setString(_login, _name);
                            }
                          },
                          child: Text(locs?.start ?? 'START CHAT'))))
            ])));
  }

  void _getBlockedUsers(SharedPreferences sp) async => openDatabase(join(await getDatabasesPath(), DB_NAME))
      .then((db) => db.query(BLOCKED_USER, where: '$LOGIN=?', whereArgs: [_login]))
      .then((value) => setState(() => _blockedUsers = value.toList()));

  _getCreds(SharedPreferences sp) async {
    setState(() {
      _login = sp.getString(LOGIN) ?? '';
      _name = sp.getString(_login) ?? '';
    });
    _getBlockedUsers(sp);
  }

  void _unblock(Map<String, Object?> m) async {
    _blockedUsers.removeWhere((uMap) => uMap[BLOCKED_LOGIN] == m[BLOCKED_LOGIN] && uMap[LOGIN] == m[LOGIN]);
    _db = await openDatabase(join(await getDatabasesPath(), DB_NAME));
    _db.delete(BLOCKED_USER, where: '$BLOCKED_LOGIN=? AND $LOGIN=?', whereArgs: [m[BLOCKED_LOGIN], m[LOGIN]]);
    FirebaseFirestore.instance.doc('user/$_login/$BLOCKED_USER/${m[BLOCKED_LOGIN]}').delete();
  }
}
