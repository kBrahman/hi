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
  var interstitialAd = InterstitialAd(
      adUnitId: _interstitialId(), request: AdRequest(), listener: AdListener(onAdClosed: (ad) => start(s)))
    ..load();
  Firebase.initializeApp();
  FlutterError.onError = (error) => flutterErrorHandler(error);
  String data = await rootBundle.loadString('assets/local.properties');
  var iterable = data.split('\n').where((element) => !element.startsWith('#') && element.isNotEmpty);
  var props = Map.fromIterable(iterable, key: (v) => v.split('=')[0], value: (v) => v.split('=')[1]);
  s = props['server'];
  if (await interstitialAd.isLoaded())
    interstitialAd.show();
  else
    Future.delayed(
        Duration(seconds: 7), () async => {if (await interstitialAd.isLoaded()) interstitialAd.show() else start(s)});
}

start(s) async {
  await [Permission.camera, Permission.microphone].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
      ? exit(0)
      : runZonedGuarded<Future<void>>(
          () async => runApp(new Call(ip: s)),
          (error, stack) async {
            debugPrint(error.toString());
            // Whenever an error occurs, call the `reportCrash`
            // to send Dart errors to Crashlytics
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
