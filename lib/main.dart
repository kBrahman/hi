import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';

import 'util/util.dart';
import 'widget/call.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  String s = 'Undefined';
  InterstitialAd? interstitialAd;
  interstitialAd = InterstitialAd(
      adUnitId: _interstitialId(),
      request: AdRequest(),
      listener: AdListener(
          onAdClosed: (ad) => start(s),
          onAdFailedToLoad: (ad, err) => start(s),
          onAdLoaded: (ad) {
            interstitialAd?.show();
            interstitialAd = null;
          }))
    ..load();
  Firebase.initializeApp();
  FlutterError.onError = (error) => flutterErrorHandler(error);
  String data = await rootBundle.loadString('assets/local.properties');
  var iterable = data.split('\n').where((element) => !element.startsWith('#') && element.isNotEmpty);
  var props = Map.fromIterable(iterable, key: (v) => v.split('=')[0], value: (v) => v.split('=')[1]);
  s = props['server'];
  Future.delayed(Duration(seconds: 6), () {
    if (interstitialAd != null) {
      interstitialAd = null;
      start(s);
    }
  });
}

start(s) async {
  hiLog('Main', 'start');
  await [Permission.camera, Permission.microphone].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
      ? exit(0)
      : runZonedGuarded<Future<void>>(
          () async => runApp(new Call(ip: s)),
          (error, stack) async {
            debugPrint(error.toString());
            FirebaseCrashlytics.instance.recordError(error, stack);
          },
        ));
}

void flutterErrorHandler(FlutterErrorDetails details) {
  FlutterError.dumpErrorToConsole(details);
  Zone.current.handleUncaughtError(details.exception, details.stack!);
}

_interstitialId() => kDebugMode ? _testInterstitialId() : _interstitialAdId();

_testInterstitialId() =>
    Platform.isAndroid ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/4411468910';

_interstitialAdId() => Platform.isAndroid ? ANDROID_INTERSTITIAL_ID : IOS_INTERSTITIAL_ID;
