import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/call/call.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String data = await rootBundle.loadString('assets/local.properties');
  var iterable = data.split('\n').where((element) => !element.startsWith('#'));
  var props = Map.fromIterable(iterable,
      key: (v) => v.split('=')[0], value: (v) => v.split('=')[1]);
  var s = props['server'];
  runApp(new Call(ip: s));
}
