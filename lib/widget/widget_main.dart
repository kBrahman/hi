// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:hi/util/util.dart';
import 'package:hi/widget/widget_terms.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_call.dart';

class MainWidget extends StatefulWidget {
  final String ip;
  final String turnServer;
  final String turnUname;
  final String turnPass;
  final bool termsAccepted;

  const MainWidget(
      {Key? key,
      required this.ip,
      required this.turnServer,
      required this.turnUname,
      required this.turnPass,
      required this.termsAccepted})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MainWidgetState();
}

class _MainWidgetState extends State<MainWidget> {
  static const TAG = '_MainWidgetState';
  late bool termsAccepted;

  @override
  void initState() {
    termsAccepted = widget.termsAccepted;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => termsAccepted
      ? CallWidget(ip: widget.ip, turnServer: widget.turnServer, turnUname: widget.turnUname, turnPass: widget.turnPass)
      : TermsWidget(() {
          setState(() => termsAccepted = true);
          SharedPreferences.getInstance().then((sp) => sp.setBool(TERMS_ACCEPTED, true));
        });
}
