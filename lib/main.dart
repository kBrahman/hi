// ignore_for_file: constant_identifier_names
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hi/widget/widget_main.dart';
import 'package:permission_handler/permission_handler.dart';

import 'l10n/locale.dart';

var colorCodes = {
  50: const Color.fromRGBO(211, 10, 75, .1),
  for (var i = 100; i < 1000; i += 100) i: Color.fromRGBO(247, 0, 15, (i + 100) / 1000)
};

void main() async {
  const TAG = 'Main';
  WidgetsFlutterBinding.ensureInitialized();
  late String turnUname;
  late String turnPass;
  await Firebase.initializeApp();
  String data = await rootBundle.loadString('assets/local.properties');
  final iterable = data.split('\n').where((element) => !element.startsWith('#') && element.isNotEmpty);
  final props = {for (final v in iterable) v.split('=')[0]: v.split('=')[1]};
  final String ip = props['server']!;
  final turnServers = props['turnServers']!.split(':').map((e) => 'turn:$e:3478');
  turnUname = props['turnUname']!;
  turnPass = props['turnPass']!;
  start(ip, turnServers, turnUname, turnPass);
}

start(String ip, Iterable<String> turnServers, String turnUname, String turnPass) async =>
    await [Permission.camera, Permission.microphone].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
        ? exit(0)
        : runApp(Hi(ip: ip, turnServers: turnServers, turnUname: turnUname, turnPass: turnPass)));

class Hi extends StatelessWidget {
  static const TAG = 'Hi';

  final String ip;
  final Iterable<String> turnServers;
  final String turnUname;
  final String turnPass;

  const Hi({Key? key, required this.ip, required this.turnServers, required this.turnUname, required this.turnPass})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate
        ],
        supportedLocales: LOCALES,
        localeResolutionCallback: (locale, supportedLocales) => supportedLocales
            .firstWhere((element) => element.languageCode == locale?.languageCode, orElse: () => supportedLocales.first),
        theme: ThemeData(
          primarySwatch: MaterialColor(0xFFE10A50, colorCodes),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MainWidget(ip: ip, turnServers: turnServers, turnUname: turnUname, turnPass: turnPass));
  }
}
