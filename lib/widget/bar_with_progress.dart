import 'package:flutter/material.dart';
import 'package:hi/bloc/bloc_sign_up.dart';

class BarWithProgress extends AppBar {
  BarWithProgress(bool progress, List<Widget>? actions, {super.title, Key? key})
      : super(
            key: key,
            actions:actions,
            bottom: progress
                ? const PreferredSize(
                    preferredSize: Size(double.infinity, 0), child: LinearProgressIndicator(backgroundColor: Colors.white))
                : null);
}
