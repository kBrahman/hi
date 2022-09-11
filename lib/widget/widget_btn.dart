// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../util/util.dart';

class HiBtn extends StatelessWidget {
  static const TAG = 'PhoneSignInBtn';
  final VoidCallback onPressed;
  final String txt;
  final Widget? icon;
  final Color txtColor;

  const HiBtn(this.onPressed, this.txt, this.icon, this.txtColor, {Key? key}) : super(key: key);

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

  getChild() {
    return Container(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 36.0),
        child: _SmartRow(children: [
          if (icon != null) icon!,
          Text(txt, style: TextStyle(color: txtColor, fontSize: 14.0, backgroundColor: const Color.fromRGBO(0, 0, 0, 0)))
        ]));
  }
}

class _SmartRow extends MultiChildRenderObjectWidget {
  static const TAG = '_SmartRow';

  _SmartRow({children}) : super(children: children);

  @override
  RenderObject createRenderObject(BuildContext context) {
    hiLog(TAG, 'children=>$children');
    if (children.length == 1) return RenderPositionedBox(alignment: Alignment.center);

    return RenderErrorBox('tst');
  }
}

class _RenderIconAndText extends RenderBox {}
