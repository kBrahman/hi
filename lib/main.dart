// ignore_for_file: constant_identifier_names

import 'dart:core';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'util/util.dart';
import 'widget/call.dart';

void main() async {
  const TAG = 'Main';
  WidgetsFlutterBinding.ensureInitialized();
  String s = 'Undefined';
  late String turnServer;
  late String turnUname;
  late String turnPass;
  var adShown = false;
  final platform = const MethodChannel('hi.channel/app')
    ..setMethodCallHandler((call) async {
      hiLog(TAG, 'method=>${call.method}');
      switch (call.method) {
        case 'displayed':
          adShown = true;
          break;
        case 'dismissed':
          start(s, turnServer, turnUname, turnPass);
      }
    });

  Firebase.initializeApp();
  String data = await rootBundle.loadString('assets/local.properties');
  final iterable = data.split('\n').where((element) => !element.startsWith('#') && element.isNotEmpty);
  final props = {for (final v in iterable) v.split('=')[0]: v.split('=')[1]};
  s = props['server']!;
  turnServer = props['turnServer']!;
  turnUname = props['turnUname']!;
  turnPass = props['turnPass']!;
  Future.delayed(const Duration(seconds: 7), () async {
    if (!adShown) {
      await platform.invokeMethod('timeOut');
      start(s, turnServer, turnUname, turnPass);
      hiLog(TAG, 'start');
    }
  });
}

start(s, String turnServer, String turnUname, String turnPass) async =>
    await [Permission.camera, Permission.microphone].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
        ? exit(0)
        : runApp(Call(ip: s, turnServer: turnServer, turnUname: turnUname, turnPass: turnPass)));



