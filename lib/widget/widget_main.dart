// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structuresud_firestore/cloud_firestore.dart';, curly_braces_in_flow_control_structuresud_firestore/cloud_firestore.dart';, curly_braces_in_flow_control_structures
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:hi/util/util.dart';
import 'package:hi/widget/widget_profile.dart';
import 'package:hi/widget/widget_sign_in_reg.dart';
import 'package:hi/widget/widget_terms.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'widget_call.dart';

class MainWidget extends StatefulWidget {
  final String ip;
  final Iterable<String> turnServers;
  final String turnUname;
  final String turnPass;

  const MainWidget({Key? key, required this.ip, required this.turnServers, required this.turnUname, required this.turnPass})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MainWidgetState();
}

class _MainWidgetState extends State<MainWidget> with WidgetsBindingObserver {
  static const TAG = '_MainWidgetState';
  UIState _uiState = UIState.LOADING;
  bool _connectedToInet = true;
  var _showPasswdForm = true;
  var _login = '';
  late Database _db;
  int _blockPeriod = 0;
  DateTime? _unblockTime;
  bool _termsAccepted = false;
  bool _signedIn = false;
  final _stateStack = <UIState>[];
  late SharedPreferences sharedPrefs;
  late String _name;

  @override
  void initState() {
    _setState();
    _initDB();
    _checkConnection();
    WidgetsBinding.instance.addObserver(this);
    hiLog(TAG, 'init');
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // SharedPreferences.getInstance().then((value) => value.setInt(TIME_LAST_ACTIVE, Timestamp.now().seconds));
        hiLog(TAG, 'paused');
        break;
      case AppLifecycleState.resumed:
        hiLog(TAG, 'resumed');
        if (_unblockTime != null && _uiState == UIState.BLOCKED && DateTime.now().isAfter(_unblockTime!)) {
          setState(() {
            _uiState = UIState.PROFILE;
            _unblockTime = null;
          });
          _db.update(TABLE_USER, {BLOCK_PERIOD: BLOCK_NO, BLOCK_TIME: 0}, where: '$LOGIN=?', whereArgs: [_login]);
          FirebaseFirestore.instance.doc('user/$_login').set({BLOCK_PERIOD: BLOCK_NO}, SetOptions(merge: true));
        } else if (_login.isNotEmpty)
          FirebaseFirestore.instance.doc('user/$_login').get().then((doc) {
            if (doc.exists && doc[BLOCK_PERIOD] != BLOCK_NO) {
              _blockUnblock(doc[BLOCK_PERIOD], doc[BLOCK_TIME], _login);
              sharedPrefs.setInt(BLOCK_PERIOD, doc[BLOCK_PERIOD]);
              final millis = (doc[BLOCK_TIME] as Timestamp).millisecondsSinceEpoch;
              sharedPrefs.setInt(BLOCK_TIME, millis);
              _db.update(TABLE_USER, {BLOCK_PERIOD: doc[BLOCK_PERIOD], BLOCK_TIME: millis, LAST_BLOCK_PERIOD: doc[BLOCK_PERIOD]},
                  where: '$LOGIN=?', whereArgs: [_login]);
            }
          });
        else {
          setState(() => getState(_signedIn, _termsAccepted));
          sharedPrefs.remove(BLOCK_PERIOD);
          sharedPrefs.remove(BLOCK_TIME);
          _db.update(TABLE_USER, {BLOCK_PERIOD: BLOCK_NO, BLOCK_TIME: 0}, where: '$LOGIN=?', whereArgs: [_login]);
        }
    }
  }

  _initDB() async => _db = await openDatabase(p.join(await getDatabasesPath(), DB_NAME), onCreate: (db, v) async {
        db.execute(
            'CREATE TABLE $TABLE_USER($LOGIN TEXT PRIMARY KEY, $COLUMN_PASSWD TEXT, $BLOCK_PERIOD INTEGER DEFAULT $BLOCK_NO, $BLOCK_TIME INTEGER, '
            '$LAST_BLOCK_PERIOD INTEGER DEFAULT $BLOCK_NO)');
        db.execute('CREATE TABLE $BLOCKED_USER($BLOCKED_LOGIN TEXT NOT NULL, $NAME TEXT, $LOGIN TEXT NOT NULL, '
            'PRIMARY KEY ($BLOCKED_LOGIN, $LOGIN), FOREIGN KEY($LOGIN) REFERENCES user($LOGIN))');
        db.execute('CREATE TABLE $REPORT($REPORTER_LOGIN TEXT NOT NULL, $LOGIN TEXT NOT NULL, '
            'PRIMARY KEY ($REPORTER_LOGIN, $LOGIN), FOREIGN KEY($LOGIN) REFERENCES user($LOGIN))');
      }, version: DB_VERSION_1);

  @override
  Widget build(BuildContext context) => getChild();

  void _startChat(name) {
    _name = name;
    setState(() => _uiState = UIState.CALL);
    _stateStack.add(UIState.CALL);
  }

  void _checkConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    setConnected(connectivityResult);
    Connectivity().onConnectivityChanged.listen((r) => setConnected(r));
  }

  void setConnected(ConnectivityResult connectivityResult) {
    var _connected = connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi;
    if (_connected != _connectedToInet)
      setState(() {
        _connectedToInet = _connected;
        hiLog(TAG, 'network change=>connected to net=>$_connectedToInet');
      });
  }

  UIState getState(bool signedIn, bool termsAccepted) => signedIn && termsAccepted
      ? UIState.PROFILE
      : termsAccepted
          ? UIState.SIGN_IN_UP
          : UIState.TERMS;

  void _exit() {
    sharedPrefs.remove(SIGNED_IN);
    sharedPrefs.remove(NAME);
    sharedPrefs.remove(BLOCK_PERIOD);
    sharedPrefs.remove(BLOCK_TIME);
    setState(() {
      _uiState = UIState.SIGN_IN_UP;
    });
  }

  _block(login, unblockTime, periodCode) {
    _login = login;
    _signedIn = true;
    _unblockTime = unblockTime;
    _blockPeriod = periodCode;
    setState(() => _uiState = UIState.BLOCKED);
  }

  _blockUnblock(int periodCode, Timestamp timestamp, String login) {
    _blockPeriod = periodCode;
    _unblockTime = timestamp.toDate().add(Duration(minutes: getMinutes(periodCode)));
    _login = login;
    _signedIn = true;
    if (DateTime.now().isBefore(_unblockTime!)) {
      setState(() => _uiState = UIState.BLOCKED);
      hiLog(TAG, 'should block now');
    } else {
      _blockPeriod = BLOCK_NO;
      _unblockTime = null;
      setState(() => _uiState = UIState.PROFILE);
      FirebaseFirestore.instance.doc('user/$login').set({BLOCK_PERIOD: BLOCK_NO}, SetOptions(merge: true));
      sharedPrefs.remove(BLOCK_PERIOD);
      sharedPrefs.remove(BLOCK_TIME);
    }
    hiLog(TAG, 'check blocked');
  }

  String getPeriod(int periodCode) {
    hiLog(TAG, 'period code=>$periodCode');
    switch (periodCode) {
      case BLOCK_WEEK:
        return 'one week';
      case BLOCK_MONTH:
        return 'one month';
      case BLOCK_QUARTER:
        return 'three months';
      case BLOCK_SEMI:
        return 'six months';
      case BLOCK_YEAR:
        return 'one year';
      case BLOCK_FOREVER:
        return 'forever';
      case BLOCK_TEST:
        return 'test';
      default:
        throw UnimplementedError();
    }
  }

  _setState() async {
    sharedPrefs = await SharedPreferences.getInstance();
    _termsAccepted = sharedPrefs.getBool(TERMS_ACCEPTED) ?? false;
    _signedIn = sharedPrefs.getBool(SIGNED_IN) ?? false;
    _login = sharedPrefs.getString(LOGIN) ?? '';
    final blocked = sharedPrefs.getInt(BLOCK_PERIOD) ?? BLOCK_NO;
    if (blocked != BLOCK_NO)
      return _blockUnblock(blocked, Timestamp(sharedPrefs.getInt(BLOCK_TIME)!, 0), _login);
    else if (_login.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.doc('user/$_login').get();
      if (doc.exists && doc[BLOCK_PERIOD] != BLOCK_NO) {
        final periodCode = doc[BLOCK_PERIOD];
        final blockTime = doc[BLOCK_TIME] as Timestamp;
        _blockUnblock(periodCode, blockTime, _login);
        sharedPrefs.setInt(BLOCK_PERIOD, periodCode);
        sharedPrefs.setInt(BLOCK_TIME, blockTime.seconds);
        return;
      }
    }
    setState(() => _uiState = getState(_signedIn, _termsAccepted));
  }

  @override
  void dispose() {
    hiLog(TAG, 'dispose');
    super.dispose();
  }

  getChild() {
    switch (_uiState) {
      case UIState.CALL:
        return CallWidget(() => setState(() => _uiState = UIState.PROFILE), _block, _db, _name,
            ip: widget.ip, turnServers: widget.turnServers, turnUname: widget.turnUname, turnPass: widget.turnPass);
      case UIState.TERMS:
        return TermsWidget(() {
          setState(() => _uiState = getState(_signedIn, true));
          SharedPreferences.getInstance().then((sp) => sp.setBool(TERMS_ACCEPTED, true));
        });
      case UIState.SIGN_IN_UP:
        return SignInOrRegWidget((login) {
          _login = login;
          _signedIn = true;
          setState(() => _uiState = UIState.PROFILE);
        }, _block, _connectedToInet);
      case UIState.PROFILE:
        return ProfileWidget(_startChat, _exit, sharedPrefs);
      case UIState.BLOCKED:
        return Scaffold(
            appBar: AppBar(title: nameWidget, actions: [IconButton(onPressed: _exit, icon: const Icon(Icons.exit_to_app))]),
            body: Center(
                child: Padding(
                    padding: edgeInsetsLR8,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Your account is blocked.', style: bold20),
                      Text('Block period:${getPeriod(_blockPeriod)}', style: bold20),
                      if (_blockPeriod != BLOCK_FOREVER)
                        Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16),
                            child: Text(
                                'Your account will be unblocked on ${DateFormat.yMMMMd().format(_unblockTime!)} at'
                                ' ${DateFormat.Hm().format(_unblockTime!)}',
                                textAlign: TextAlign.center))
                    ]))));
      case UIState.LOADING:
        return Scaffold(appBar: appBarWithTitle, body: const Center(child: CircularProgressIndicator()));
      default:
        throw UnimplementedError();
    }
  }
}

enum UIState { SIGN_IN_UP, PROFILE, CALL, TERMS, BLOCKED, LOADING }
