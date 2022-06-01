// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

class HiBtn extends StatelessWidget {
  static const TAG = 'PhoneSignInBtn';
  final VoidCallback onPressed;
  final String txt;
  final IconData? icon;
  final Color txtColor;

  const HiBtn(this.onPressed, this.txt, this.icon, this.txtColor,
      {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      onPressed: onPressed,
      textColor: const Color.fromRGBO(0, 0, 0, 0.54),
      color: Colors.white,
      child: getChild(),
      padding: const EdgeInsets.all(0),
      splashColor: Colors.white10,
      highlightColor: Colors.white10,
    );
  }

  getChild() => Container(
        constraints: const BoxConstraints(
          maxWidth: 220,
          maxHeight: 36.0,
        ),
        child: Stack(
          fit: StackFit.expand,
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: const EdgeInsets.only(left: 13),
                    child: Icon(icon))),
            Center(
                child: Text(
              txt,
              style: TextStyle(
                color: txtColor,
                fontSize: 14.0,
                backgroundColor: const Color.fromRGBO(0, 0, 0, 0),
              ),
            )),
          ],
        ),
      );
}
