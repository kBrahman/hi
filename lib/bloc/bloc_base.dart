// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/services.dart';

class BaseBloc {
  static final _ctr = StreamController<GlobalEvent>();
  static bool connectedToInet = true;
  final platform = const MethodChannel('hi.channel/app')..setMethodCallHandler(nativeMethodCallHandler);

  Stream<GlobalEvent> get globalStream => _ctr.stream;

  Sink<GlobalEvent> get globalSink => _ctr.sink;

  get hasListener => _ctr.hasListener;

  static Future<dynamic> nativeMethodCallHandler(MethodCall methodCall) async {
    final method = methodCall.method;
    switch (method) {
      case "onAvailable":
        connectedToInet = true;
        break;
      case "onLost":
        connectedToInet = false;
    }
  }
}

enum GlobalEvent { ERR_TERMS, BLOCK, PROFILE, SIGN_IN, PERMISSION_PERMANENTLY_DENIED, PERMISSION_DENIED, NO_INTERNET, ERR_CONN, REPORT_SENT }
