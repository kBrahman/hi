import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/call/call.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String data = await rootBundle.loadString('assets/local.properties');
  var iterable = data.split('\n').where((element) => !element.startsWith('#'));
  var props = Map.fromIterable(iterable,
      key: (v) => v.split('=')[0], value: (v) => v.split('=')[1]);
  var s = props['server'];
  await [
    Permission.camera,
    Permission.microphone,
  ].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
      ? exit(0)
      : runApp(new Call(ip: s)));
}
