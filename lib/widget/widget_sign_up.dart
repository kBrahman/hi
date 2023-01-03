// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hi/widget/bar_with_progress.dart';

import '../bloc/bloc_sign_up.dart';
import '../data/data_sign_up.dart';
import '../util/util.dart';

class SignUpWidget extends StatelessWidget {
  static const _TAG = 'SignUpWidget';
  final SignUpBloc _bloc;

  const SignUpWidget(this._bloc, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<SignUpData>(
        initialData: const SignUpData(),
        stream: _bloc.stream,
        builder: (context, snap) {
          final data = snap.data!;
          if (data.pop) WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
          return Scaffold(
              appBar: BarWithProgress(
                  data.progress,
                  data.state == SignUpState.SAVE
                      ? [IconButton(onPressed: () => _bloc.ctr.add(CmdSignUp.OBSCURE), icon: const Icon(Icons.remove_red_eye))]
                      : null,
                  title: Text(l10n?.sign_up ?? 'Sign up')),
              body: Center(child: _getChild(l10n, data)));
        });
  }

  _getChild(AppLocalizations? l10n, SignUpData data) {
    hiLog(_TAG, 'data:$data');
    final state = data.state;
    switch (state) {
      case SignUpState.PHONE:
        return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (data.time > 0) Text((l10n?.can_send_after ?? 'You can send after:') + data.time.toString()),
              if (data.phoneInvalid)
                Text(l10n?.phone_invalid ?? 'Invalid phone number', style: const TextStyle(fontSize: 13, color: Colors.red))
              else if (data.tooMany)
                Text(l10n?.too_many ?? 'Too many requests, try again later please',
                    style: const TextStyle(fontSize: 13, color: Colors.red)),
              TextField(
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  controller: _bloc.txtCtrPhone,
                  decoration: InputDecoration(
                      hintText: l10n?.phone ?? 'phone number',
                      prefixText: _isRTL() ? null : '+',
                      suffixText: _isRTL() ? '+' : null),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  keyboardType: TextInputType.phone),
              ElevatedButton(
                  onPressed: () =>
                      _bloc.txtCtrPhone.text.isEmpty || data.progress || data.time > 0 ? null : _bloc.ctr.add(CmdSignUp.SEND_NUM),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(l10n?.next ?? 'NEXT')]))
            ]));
      case SignUpState.SMS:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${l10n?.sms ?? 'SMS is sent to'}: ${_bloc.txtCtrPhone.text}'),
          if (data.codeInvalid) Text(l10n?.sms_invalid ?? 'Invalid SMS code', style: const TextStyle(color: Colors.red)),
          Row(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final enabled = index == data.focusIndex;
                return Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 4, right: index == 5 ? 0 : 4),
                    child: SizedBox(
                        width: 40,
                        child: TextField(
                            textDirection: TextDirection.ltr,
                            key: (index == data.focusIndex) ? UniqueKey() : null,
                            enabled: enabled,
                            controller: _bloc.smsControllers.elementAt(index),
                            autofocus: enabled,
                            showCursor: false,
                            style: const TextStyle(fontSize: 30),
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number)));
              })),
          const SizedBox(height: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Row(children: [
                Expanded(
                    child: ElevatedButton(onPressed: () => _bloc.ctr.add(CmdSignUp.BACK), child: Text(l10n?.back ?? 'BACK'))),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton(
                        onPressed: () => data.progress || _bloc.smsControllers.any((c) => c.text.isEmpty)
                            ? null
                            : _bloc.ctr.add(CmdSignUp.SUBMIT),
                        child: Text(l10n?.next ?? 'NEXT')))
              ]))
        ]);
      case SignUpState.SAVE:
        return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _bloc.txtCtrPass,
                  builder: (ctx, v, ch) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('1. ${l10n?.lowercase ?? 'Password must contain lowercase letters'}',
                            style: TextStyle(
                                fontSize: 11,
                                color: v.text.contains(RegExp(r'\p{Ll}', unicode: true)) ? Colors.green : Colors.red)),
                        Text('2. ${l10n?.uppercase ?? ' Password must contain uppercase letters'}',
                            style: TextStyle(
                                fontSize: 11,
                                color: v.text.contains(RegExp(r'\p{Lu}', unicode: true)) ? Colors.green : Colors.red)),
                        Text('3. ${l10n?.nums ?? 'Password must contain numbers'}',
                            style: TextStyle(fontSize: 11, color: v.text.contains(RegExp(r'\d')) ? Colors.green : Colors.red)),
                        Text('4. ${l10n?.min_len ?? ' Password minimum length is 8'}',
                            style: TextStyle(fontSize: 11, color: v.text.length > 7 ? Colors.green : Colors.red)),
                        ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _bloc.txtCtrRePass,
                            builder: (ctx, v, ch) {
                              final pass = _bloc.txtCtrPass.text;
                              return Text('5. ${l10n?.match ?? 'Passwords must match'}',
                                  style: TextStyle(
                                      fontSize: 11, color: pass.isNotEmpty && pass == v.text ? Colors.green : Colors.red));
                            })
                      ])),
              TextField(
                autofocus: true,
                enableInteractiveSelection: false,
                obscureText: data.obscure,
                controller: _bloc.txtCtrPass,
                style: const TextStyle(fontSize: 20),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: l10n?.passwd ?? "password",
                ),
              ),
              TextField(
                enableInteractiveSelection: false,
                obscureText: data.obscure,
                style: const TextStyle(fontSize: 20),
                controller: _bloc.txtCtrRePass,
                decoration: InputDecoration(hintText: l10n?.retype ?? 'retype password'),
              ),
              ElevatedButton(
                  onPressed: () => data.progress || !_valid(_bloc.txtCtrPass.text, _bloc.txtCtrRePass.text)
                      ? null
                      : _bloc.ctr.add(CmdSignUp.SAVE),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(l10n?.next ?? 'NEXT')]))
            ]));
    }
  }

  bool _valid(String pass, String rePass) =>
      pass.contains(RegExp(r'\p{Ll}', unicode: true)) &&
      pass.contains(RegExp(r'\p{Lu}', unicode: true)) &&
      pass.contains(RegExp(r'\d')) &&
      pass.length > 7 &&
      pass == rePass;

  _isRTL() => ['ar', 'iw', 'fa', 'ur'].contains(Platform.localeName.substring(0, 2));
}
