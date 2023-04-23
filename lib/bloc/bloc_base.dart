// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hi/util/util.dart';

abstract class BaseBloc<D, C> {
  static const _TAG = 'BaseBloc';
  static final _ctr = StreamController<GlobalEvent>();
  static bool connectedToInet = true;
  final platform = const MethodChannel('hi.channel/app');

  Stream<GlobalEvent> get globalStream => _ctr.stream;

  Sink<GlobalEvent> get globalSink => _ctr.sink;
  final ctr = StreamController<C>();

  late Stream<D> stream;

  get hasListener => _ctr.hasListener;

  BaseBloc() {
    platform.setMethodCallHandler(nativeMethodCallHandler);
    hiLog(_TAG, 'base bloc');
  }

  onLost();

  onPop(){}

  Future<dynamic> nativeMethodCallHandler(MethodCall methodCall) async {
    final method = methodCall.method;
    switch (method) {
      case 'onAvailable':
        connectedToInet = true;
        break;
      case 'onLost':
        connectedToInet = false;
        onLost();
        break;
      case 'pop':
        onPop();
    }
  }
}

enum GlobalEvent {
  ERR_TERMS,
  BLOCK,
  PROFILE,
  SIGN_IN,
  PERMISSION_PERMANENTLY_DENIED,
  PERMISSION_DENIED,
  NO_INTERNET,
  ERR_CONN,
  REPORT_SENT,
  ERR_MAIL_RU
}
