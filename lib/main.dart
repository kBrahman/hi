import 'dart:core';
import 'dart:io';

import 'package:admob_flutter/admob_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/call/call.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Admob.initialize();
  String data = await rootBundle.loadString('assets/local.properties');
  var iterable = data
      .split('\n')
      .where((element) => !element.startsWith('#') && element.isNotEmpty);
  print('l=>${iterable.length}');
  var props = Map.fromIterable(iterable,
      key: (v) => v.split('=')[0], value: (v) => v.split('=')[1]);
  var s = props['server'];
  if (Platform.isIOS) {
    await Admob.requestTrackingAuthorization();
  }
  await [
    Permission.camera,
    Permission.microphone,
  ].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
      ? exit(0)
      : runApp(new Call(ip: s)));
}
