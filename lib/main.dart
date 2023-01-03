// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hi/bloc/bloc_profile.dart';
import 'package:hi/util/util.dart';
import 'package:hi/widget/widget_blocked.dart';
import 'package:hi/widget/widget_profile.dart';
import 'package:hi/widget/widget_sign_in.dart';
import 'package:hi/widget/widget_terms.dart';

import 'bloc/bloc_base.dart';
import 'bloc/bloc_main.dart';
import 'bloc/bloc_sign_in.dart';
import 'l10n/locale.dart';

var colorCodes = {
  50: const Color.fromRGBO(211, 10, 75, .1),
  for (var i = 100; i < 1000; i += 100) i: Color.fromRGBO(247, 0, 15, (i + 100) / 1000)
};

void main() async {
  const TAG = 'main';
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(Hi(MainBloc()));
}

class Hi extends StatelessWidget {
  static const _TAG = 'Hi';
  final MainBloc _mainBloc;

  final _msgKey = GlobalKey<ScaffoldMessengerState>();

  Hi(this._mainBloc, {Key? key}) : super(key: key);

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
        scaffoldMessengerKey: _msgKey,
        home: _getHome());
  }

  Widget _getHome() {
    WidgetsBinding.instance.addPostFrameCallback(_observeGlobalEvent);
    return StreamBuilder<UiState>(
        initialData: UiState.LOADING,
        stream: _mainBloc.stream,
        builder: (context, snap) {
          final state = snap.data!;
          hiLog(_TAG, 'state=>$state');
          switch (state) {
            case UiState.TERMS:
              return TermsWidget(_mainBloc);
            case UiState.LOADING:
              return Scaffold(
                  appBar: AppBar(
                    title: const Text('hi'),
                  ),
                  body: const Center(child: CircularProgressIndicator()));
            case UiState.SIGN_IN:
              return SignInWidget(SignInBloc());
            case UiState.BLOCKED:
              return BlockedWidget(_mainBloc);
            case UiState.PROFILE:
              return ProfileWidget(ProfileBloc());
            default:
              throw 'not implemented';
          }
        });
  }

  Future<void> _observeGlobalEvent(_) async {
    hiLog(_TAG, '_globalEventListener');
    final context = _msgKey.currentState?.context;
    if (_mainBloc.hasListener || context == null) return;
    final l10n = AppLocalizations.of(context);
    await for (final e in _mainBloc.globalStream) {
      hiLog(_TAG, 'global event=>$e');
      switch (e) {
        case GlobalEvent.ERR_TERMS:
          _showSnack(l10n?.err_terms ?? 'Could not save your answer, try again please', 3);
          break;
        case GlobalEvent.BLOCK:
          _mainBloc.ctr.add(Cmd.BLOCK);
          break;
        case GlobalEvent.PROFILE:
          _mainBloc.ctr.add(Cmd.PROFILE);
          break;
        case GlobalEvent.SIGN_IN:
          _mainBloc.ctr.add(Cmd.SIGN_IN);
          break;
        case GlobalEvent.PERMISSION_PERMANENTLY_DENIED:
          _msgKey.currentState?.showSnackBar(SnackBar(
              content: Row(children: [
                Expanded(
                    child: Text(l10n?.open_settings ?? 'Please go to settings and give access to your camera and microphone')),
                TextButton(
                    onPressed: () => _mainBloc.platform.invokeMethod('appSettings'), child: Text(l10n?.settings ?? 'SETTINGS'))
              ]),
              duration: const Duration(seconds: 6)));
          break;
        case GlobalEvent.PERMISSION_DENIED:
          _showSnack(l10n?.need_access ?? 'Please grant access to your camera and microphone!', 2);
          break;
        case GlobalEvent.NO_INTERNET:
          _showSnack(l10n?.no_inet ?? 'No internet access', 2);
          break;
        case GlobalEvent.ERR_CONN:
          _showSnack(l10n?.err_conn ?? 'Connection error, try again please', 2);
          break;
        case GlobalEvent.REPORT_SENT:
          _showSnack(l10n?.report_sent ?? 'Complaint sent', 3);
          break;
        case GlobalEvent.ERR_MAIL_RU:
          _showSnack(l10n?.mail_ru_problem ?? 'Email sign in does not work with mail.ru, try other email please', 3);
      }
    }
  }

  void _showSnack(String s, dur) {
    hiLog(_TAG, '_showSnack');
    final snackBar = SnackBar(content: Text(s), duration: Duration(seconds: dur));
    _msgKey.currentState?.showSnackBar(snackBar);
  }
}

enum UiState { LOADING, BLOCKED, PROFILE, SIGN_IN, TERMS }
