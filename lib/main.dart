// ignore_for_file: constant_identifier_names

import 'dart:core';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';

import 'util/util.dart';
import 'widget/call.dart';

void main() async {
  const TAG = 'Main';
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  String s = 'Undefined';
  late String turnServer;
  late String turnUname;
  late String turnPass;
  InterstitialAd? interstitialAd;
  var timedOut = false;
  InterstitialAd.load(
      adUnitId: _interstitialId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (InterstitialAd ad) {
        if (timedOut) {
          ad.dispose();
          return;
        }
        interstitialAd = ad
          ..fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
            start(s, turnServer, turnUname, turnPass);
            ad.dispose();
          });
        interstitialAd?.show();
      }, onAdFailedToLoad: (LoadAdError error) {
        hiLog(TAG, 'ad failed to load=>$error');
        if (timedOut) return;
        start(s, turnServer, turnUname, turnPass);
        timedOut = true;
      }));
  Firebase.initializeApp();
  String data = await rootBundle.loadString('assets/local.properties');
  final iterable = data.split('\n').where((element) => !element.startsWith('#') && element.isNotEmpty);
  final props = {for (final v in iterable) v.split('=')[0]: v.split('=')[1]};
  s = props['server']!;
  turnServer = props['turnServer']!;
  turnUname = props['turnUname']!;
  turnPass = props['turnPass']!;
  Future.delayed(const Duration(seconds: 7), () {
    if (interstitialAd == null && !timedOut) {
      timedOut = true;
      start(s, turnServer, turnUname, turnPass);
    }
  });
}

start(s, String turnServer, String turnUname, String turnPass) async =>
    await [Permission.camera, Permission.microphone].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
        ? exit(0)
        : runApp(Call(ip: s, turnServer: turnServer, turnUname: turnUname, turnPass: turnPass)));

_interstitialId() => kDebugMode ? _testInterstitialId() : _interstitialAdId();

_testInterstitialId() => Platform.isAndroid ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/4411468910';

_interstitialAdId() => Platform.isAndroid ? ANDROID_INTERSTITIAL_ID : IOS_INTERSTITIAL_ID;
