import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/bloc/bloc_main.dart';
import 'package:hi/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/util.dart';

class TermsWidget extends StatelessWidget {
  final MainBloc _mainBloc;

  const TermsWidget(this._mainBloc, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: const Text('hi')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(l10n?.terms_title ?? 'Terms of user/user policy',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(AppLocalizations.of(context)?.terms ?? TERMS_DEFAULT, style: const TextStyle(fontSize: 17)))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
                onPressed: () => SharedPreferences.getInstance().then((sp) => sp.setBool(TERMS_ACCEPTED, true)).then((accepted) =>
                    accepted ? _mainBloc.sink.add(Cmd.SIGN_IN) : _mainBloc.globalSink.add(GlobalEvent.ERR_TERMS)),
                child: Text(AppLocalizations.of(context)?.accept ?? 'ACCEPT')),
            TextButton(onPressed: SystemNavigator.pop, child: Text(AppLocalizations.of(context)?.decline ?? 'DECLINE'))
          ])
        ]));
  }
}
