// ignore_for_file: constant_identifier_names, avoid_print, curly_braces_in_flow_control_structures

library random_string;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const TERMS_DEFAULT =
    "'Zhet' ('we' or 'us' or 'our') respects human dignity of our users ('user' or 'you'). We do not support any kind of discrimination, threats, bullying, harassment and abuse. This Terms of user/user Policy explains how we moderate such an objectionable content which features discrimination, threats, bullying, harassment or abuse. Please read this Policy carefully. IF YOU DO NOT AGREE WITH THE TERMS OF THIS POLICY, PLEASE DO NOT ACCESS THE APPLICATION.\nWe reserve the right to make changes to this Policy at any time and for any reason. You MUST accept the terms of this policy in order to use the app\n\nOBJECTIONABLE CONTENT AND BEHAVIORS:\nWe define any kind of discrimination, threats, bullying, harassment and abuse as objectionable behavior.\nWe define sexually explicit content as objectionable content.\n\nAPP USAGE:\nWhile using this app you agree not to expose objectionable content or behaviors against any other user. If you violate the terms of this Policy you will be temporarily banned from using this app. In case of continued violation, i.e. if we keep getting complaint reports from other users on your account, your account will be terminated and you will never ever be able to use this app.";
const ASCII_START = 33;
const ASCII_END = 126;
const NUMERIC_START = 48;
const NUMERIC_END = 57;
const LOWER_ALPHA_START = 97;
const LOWER_ALPHA_END = 122;
const UPPER_ALPHA_START = 65;
const UPPER_ALPHA_END = 90;
const ANDROID_BANNER_ID = 'ca-app-pub-8761730220693010/9359738284';
const IOS_BANNER_ID = 'ca-app-pub-8761730220693010/8787379216';
const ANDROID_INTERSTITIAL_ID = 'ca-app-pub-8761730220693010/2067844692';
const IOS_INTERSTITIAL_ID = 'ca-app-pub-8761730220693010/7838433087';
const ICE_RESTART_COUNT_THRESHOLD = 2;
const TERMS_ACCEPTED = 'terms_accepted';
const IS_SIGNED_IN = 'signed_in';
const VERIFICATION_DATA = 'verification_data';
const PIN_CODE = 'pin_code';
const DB_NAME = 'hi.db';
const DB_VERSION_2 = 2;
const USER = 'user';
const REPORT = 'report';
const UPDATE = 'update';
const ANSWER = 'answer';
const CANDIDATE = 'candidate';
const BYE = 'bye';
const BLOCKED_USER = 'blocked_user';
const LOGIN = 'login';
const PEER_LOGIN = 'peer_login';
const BLOCKED_PEER = 'blocked_peer';
const PASSWD = 'passwd';
const NAME = 'name';
const BLOCK_TIME = 'block_time';
const BLOCK_PERIOD_INDEX = 'block_period_index';
const LAST_BLOCK_PERIOD = 'last_block_period';
const BLOCK = 'block';
const TIME_LAST_ACTIVE = 'time_last_active';
const PEER = 'peer';
const OFFER = 'offer';
const sizedBox_w_8 = SizedBox(width: 8);
const bold20 = TextStyle(fontWeight: FontWeight.bold, fontSize: 20);
const edgeInsetsLR8 = EdgeInsets.only(left: 8, right: 8);
const IS_BLOCKED = 'is_blocked';
final Future<Database> dbGlobal = _getDB();

hiLog(String tag, String msg) => print('$tag:$msg');

int getMilliseconds(BlockPeriod blockPeriod) {
  switch (blockPeriod) {
    case BlockPeriod.TEST:
      return 3 * Duration.millisecondsPerMinute;
    case BlockPeriod.WEEK:
      return 7 * Duration.millisecondsPerDay;
    case BlockPeriod.MONTH:
      return 30 * Duration.millisecondsPerDay;
    case BlockPeriod.QUARTER:
      return 90 * Duration.millisecondsPerDay;
    case BlockPeriod.SEMI:
      return 182 * Duration.millisecondsPerDay;
    case BlockPeriod.YEAR:
      return 365 * Duration.millisecondsPerDay;
    case BlockPeriod.FOREVER:
      return 0;
  }
}

Future<Database> _getDB() async => openDatabase(join(await getDatabasesPath(), DB_NAME), onCreate: (db, v) {
      db.execute('CREATE TABLE $USER($LOGIN TEXT PRIMARY KEY, $PASSWD TEXT, $NAME TEXT)');

      db.execute('CREATE TABLE $BLOCKED_PEER($PEER_LOGIN TEXT NOT NULL, $NAME TEXT, $LOGIN TEXT NOT NULL, '
          'PRIMARY KEY($PEER_LOGIN, $LOGIN), FOREIGN KEY($LOGIN) REFERENCES $USER($LOGIN))');

      db.execute('CREATE TABLE $REPORT($PEER_LOGIN TEXT NOT NULL, $LOGIN TEXT NOT NULL, '
          'PRIMARY KEY ($PEER_LOGIN, $LOGIN), FOREIGN KEY($LOGIN) REFERENCES user($LOGIN))');
    }, onUpgrade: (db, oldV, newV) {
      db.execute('ALTER TABLE $BLOCKED_USER RENAME COLUMN blocked_login TO $PEER_LOGIN');
      db.execute('ALTER TABLE $BLOCKED_USER RENAME TO $BLOCKED_PEER');
      db.execute('ALTER TABLE $USER ADD COLUMN $NAME TEXT');
      db.execute('ALTER TABLE $USER DROP COLUMN block_period');
      db.execute('ALTER TABLE $USER DROP COLUMN $BLOCK_TIME');
      db.execute('ALTER TABLE $USER DROP COLUMN $LAST_BLOCK_PERIOD');
      db.execute('ALTER TABLE $REPORT RENAME COLUMN reporter_login TO $PEER_LOGIN');
      hiLog('DB', 'upgraded DB');
    }, version: DB_VERSION_2);

/*
Version 1
db.execute(
          'CREATE TABLE $TABLE_USER($LOGIN TEXT PRIMARY KEY, $PASSWD TEXT, $BLOCK_PERIOD INTEGER DEFAULT $BLOCK_NO, $BLOCK_TIME INTEGER, '
          '$LAST_BLOCK_PERIOD INTEGER DEFAULT $BLOCK_NO)');

      db.execute('CREATE TABLE $BLOCKED_USER($BLOCKED_LOGIN TEXT NOT NULL, $NAME TEXT, $LOGIN TEXT NOT NULL, '
          'PRIMARY KEY ($BLOCKED_LOGIN, $LOGIN), FOREIGN KEY($LOGIN) REFERENCES $TABLE_USER($LOGIN))');

      db.execute('CREATE TABLE $REPORT($REPORTER_LOGIN TEXT NOT NULL, $LOGIN TEXT NOT NULL, '
          'PRIMARY KEY ($REPORTER_LOGIN, $LOGIN), FOREIGN KEY($LOGIN) REFERENCES user($LOGIN))');
*/

updateDBWithBlockedUsersAndReporters(Database db, String login) async {
  final blockedUsers = (await FirebaseFirestore.instance.collection('user/$login/$BLOCKED_USER').get()).docs;
  for (final u in blockedUsers) db.insert(BLOCKED_USER, {PEER_LOGIN: u.id, NAME: u[NAME], LOGIN: login});
  final reporters = (await FirebaseFirestore.instance.collection('user/$login/$REPORT').get()).docs;
  for (final u in reporters) db.insert(REPORT, {PEER_LOGIN: u.id, LOGIN: login});
}

enum BlockPeriod { TEST, WEEK, MONTH, QUARTER, SEMI, YEAR, FOREVER }
