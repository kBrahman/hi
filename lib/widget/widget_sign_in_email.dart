import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hi/bloc/bloc_sign_in_email.dart';
import 'package:hi/data/data_email_sign_in.dart';
import 'package:hi/widget/bar_with_progress.dart';

class EmailSignInWidget extends StatelessWidget {
  final EmailSignInBloc _bloc;

  const EmailSignInWidget(this._bloc, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<EmailSignInData>(
        initialData: const EmailSignInData(),
        stream: _bloc.stream,
        builder: (context, snap) {
          final data = snap.data!;
          final login = _bloc.txtCtrEmail.text;
          return Scaffold(
              appBar: BarWithProgress(data.progress,null, title: Text(l10n?.sign_in_email ?? 'Sign in with email')),
              body: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (data.emailInvalid)
                          Text(l10n?.format_err ?? "Format is wrong", style: const TextStyle(fontSize: 13, color: Colors.red)),
                        TextField(
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 20),
                          controller: _bloc.txtCtrEmail,
                          decoration: InputDecoration(hintText: l10n?.email ?? 'Enter your email'),
                          onSubmitted: (_) => _bloc.ctr.add(Cmd.SIGN_IN),
                        ),
                        ElevatedButton(
                            onPressed: () => _bloc.ctr.add(Cmd.SIGN_IN),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [const Icon(Icons.done), Text(l10n?.sign_in ?? 'Sign in')])),
                        if (data.emailSent)
                          Row(children: [
                            Expanded(child: Text(l10n?.email_sent(login) ?? 'Email is sent to $login.  Check SPAM also.')),
                            TextButton(onPressed: _openEmail, child: Text(l10n?.open ?? 'OPEN'))
                          ])
                      ]))));
        });
  }

  void _openEmail() => _bloc.platform.invokeMethod('startEmailApp', [_bloc.txtCtrEmail.text.split('@')[1]]);
}
