import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../util/util.dart';

class TermsWidget extends StatelessWidget {
  final VoidCallback onAccept;

  const TermsWidget(this.onAccept, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: appBarWithTitle,
        body: Column(
          children: [
            Text(AppLocalizations.of(context)?.terms_title ?? 'Terms of user/user policy',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(AppLocalizations.of(context)?.terms ?? TERMS_DEFAULT, style: const TextStyle(fontSize: 17)))),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: onAccept, child: Text(AppLocalizations.of(context)?.accept ?? 'ACCEPT')),
                TextButton(onPressed: SystemNavigator.pop, child: Text(AppLocalizations.of(context)?.decline ?? 'DECLINE'))
              ],
            )
          ],
        ));
  }
}
