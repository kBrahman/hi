import 'dart:async';
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
  InterstitialAd? interstitialAd;
  var timedOut = false;
  InterstitialAd.load(
      adUnitId: _interstitialId(),
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (InterstitialAd ad) {
        if (timedOut) {
          ad.dispose();
          return;
        }
        interstitialAd = ad
          ..fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
            start(s);
            ad.dispose();
          });
        interstitialAd?.show();
      }, onAdFailedToLoad: (LoadAdError error) {
        hiLog(TAG, 'ad failed to load=>$error');
        if(timedOut)return;
        start(s);
        timedOut=true;
      }));
  Firebase.initializeApp();
  String data = await rootBundle.loadString('assets/local.properties');
  var iterable = data.split('\n').where((element) => !element.startsWith('#') && element.isNotEmpty);
  var props = Map.fromIterable(iterable, key: (v) => v.split('=')[0], value: (v) => v.split('=')[1]);
  s = props['server'];
  Future.delayed(Duration(seconds: 6), () {
    if (interstitialAd == null && !timedOut) {
      timedOut = true;
      start(s);
    }
  });
}

start(s) async => await [Permission.camera, Permission.microphone]
    .request()
    .then((statuses) => statuses.values.any((e) => !e.isGranted) ? exit(0) : runApp(Call(ip: s)));

_interstitialId() => kDebugMode ? _testInterstitialId() : _interstitialAdId();

_testInterstitialId() =>
    Platform.isAndroid ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/4411468910';

_interstitialAdId() => Platform.isAndroid ? ANDROID_INTERSTITIAL_ID : IOS_INTERSTITIAL_ID;
