// ignore_for_file: constant_identifier_names

library random_string;

import 'dart:math';

import 'package:flutter/services.dart';

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

/// Generates a random integer where [from] <= [to].
int randomBetween(int from, int to) {
  if (from > to) throw new Exception('$from cannot be > $to');
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
