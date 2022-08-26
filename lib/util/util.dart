// ignore_for_file: constant_identifier_names, avoid_print, curly_braces_in_flow_control_structures

library random_string;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

const TERMS_DEFAULT =
    "'Zhet' ('we' or 'us' or 'our') respects human dignity of our users ('user' or 'you'). We do not support any kind of discrimination, threats, bullying, harassment and abuse. This Terms of user/user Policy explains how we moderate such an objectionable content which features discrimination, threats, bullying, harassment or abuse. Please read this Policy carefully. IF YOU DO NOT AGREE WITH THE TERMS OF THIS POLICY, PLEASE DO NOT ACCESS THE APPLICATION.\nWe reserve the right to make changes to this Policy at any time and for any reason. You MUST accept the terms of this policy in order to use the app\n\nOBJECTIONABLE CONTENT AND BEHAVIORS:\nWe define any kind of discrimination, threats, bullying, harassment and abuse as objectionable behavior.\nWe define sexually explicit content as objectionable content.\n\nAPP USAGE:\nWhile using this app you agree not to expose objectionable content or behaviors against any other user. If you violate the terms of this Policy you will be temporarily banned from using this app. In case of continued violation, i.e. if we keep getting complaint reports from other users on your account, your account will be terminated and you will never ever be able to use this app.";
const ACTION_SWITCH_CAMERA = 0;
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
const SIGNED_IN = 'signed_in';
const VERIFICATION_DATA = 'verification_data';
const PIN_CODE = 'pin_code';
const DB_NAME = 'hi.db';
const DB_VERSION_1 = 1;
const TABLE_USER = 'user';
const REPORT = 'report';
const ANSWER = 'answer';
const CANDIDATE = 'candidate';
const BLOCKED_USER = 'blocked_user';
const LOGIN = 'login';
const BLOCKED_LOGIN = 'blocked_login';
const REPORTER_LOGIN = 'reporter_login';
const PASSWD = 'passwd';
const NAME = 'name';
const BLOCK_NO = 0;
const BLOCK_WEEK = 1;
const BLOCK_MONTH = 2;
const BLOCK_QUARTER = 3;
const BLOCK_SEMI = 4;
const BLOCK_YEAR = 5;
const BLOCK_FOREVER = 6;
const BLOCK_TEST = 7;
const BLOCK_TIME = 'block_time';
const BLOCK_PERIOD = 'block_period';
const LAST_BLOCK_PERIOD = 'last_block_period';
const BLOCK = 'block';
const TIME_OUT_MINIMIZED = 80;
const TIME_LAST_ACTIVE = 'time_last_active';
const PEER = 'peer';
const OFFER = 'offer';
const sizedBox_w_4 = SizedBox(width: 4);
const sizedBox_h_8 = SizedBox(height: 8);
const sizedBox_w_8 = SizedBox(width: 8);
const nameWidget = Text('hi');
const bold20 = TextStyle(fontWeight: FontWeight.bold, fontSize: 20);
const edgeInsetsLR8 = EdgeInsets.only(left: 8, right: 8);
final appBarWithTitle = AppBar(title: nameWidget);
const platform = MethodChannel('hi.channel/app');

void showSnack(String s, int dur, ctx) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(s), duration: Duration(seconds: dur)));

/// Generates a random integer where [from] <= [to].
int randomBetween(int from, int to) {
  if (from > to) throw Exception('$from cannot be > $to');
  var rand = Random();
  return ((to - from) * rand.nextDouble()).toInt() + from;
}

/// Generates a random string of [length] with characters
/// between ascii [from] to [to].
/// Defaults to characters of ascii '!' to '~'.
String randomString(int length, {int from: ASCII_START, int to: ASCII_END}) {
  return String.fromCharCodes(List.generate(length, (index) => randomBetween(from, to)));
}

/// Generates a random string of [length] with only numeric characters.
String randomNumeric(int length) => randomString(length, from: NUMERIC_START, to: NUMERIC_END);

hiLog(String tag, String msg) => print('$tag:$msg');

getMinutes(int periodCode) {
  const minutesInDay = 24 * 60;
  switch (periodCode) {
    case BLOCK_WEEK:
      return 7 * minutesInDay;
    case BLOCK_MONTH:
      return 30 * minutesInDay;
    case BLOCK_QUARTER:
      return 90 * minutesInDay;
    case BLOCK_SEMI:
      return 182 * minutesInDay;
    case BLOCK_YEAR:
      return 365 * minutesInDay;
    case BLOCK_FOREVER:
      return 0;
    case BLOCK_TEST:
      return 2;
    default:
      throw UnimplementedError();
  }
}

updateDBWithBlockedUsersAndReporters(Database db, String login) async {
  final blockedUsers = (await FirebaseFirestore.instance.collection('user/$login/$BLOCKED_USER').get()).docs;
  for (final u in blockedUsers) db.insert(BLOCKED_USER, {BLOCKED_LOGIN: u.id, NAME: u[NAME], LOGIN: login});
  final reporters = (await FirebaseFirestore.instance.collection('user/$login/$REPORT').get()).docs;
  for (final u in reporters) db.insert(REPORT, {REPORTER_LOGIN: u.id, LOGIN: login});
}
