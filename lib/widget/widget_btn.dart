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
        child: _SmartIconTxtBtn(children: [
          if (icon != null) icon!,
          Text(txt, style: TextStyle(color: txtColor, fontSize: 14.0, backgroundColor: const Color.fromRGBO(0, 0, 0, 0)))
        ]));
  }
}

class _SmartIconTxtBtn extends MultiChildRenderObjectWidget {
  static const TAG = '_SmartIconTxtBtn';

  _SmartIconTxtBtn({key, children}) : super(key: key, children: children);

  @override
  RenderBox createRenderObject(BuildContext context) => _RenderIconAndText();
}

class _BranchComponentParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderIconAndText extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BranchComponentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BranchComponentParentData> {
  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) child.parentData = _BranchComponentParentData();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    firstChild?.layout(constraints.loosen(), parentUsesSize: true);
    lastChild?.layout(constraints.loosen(), parentUsesSize: true);
    final offset1Y = (constraints.maxHeight - firstChild!.size.height) / 2;
    final offset2Y = (constraints.maxHeight - lastChild!.size.height) / 2;
    var offset2X = (constraints.maxWidth - lastChild!.size.width) / 2;
    var data = firstChild?.parentData as _BranchComponentParentData;
    if (childCount == 1) {
      data = lastChild?.parentData as _BranchComponentParentData;
      data.offset = Offset(offset2X, offset2Y);
      return;
    }
    const iconLeftPadding = 8.0;
    const spaceBetween = 4.0;
    // (firstChild as RenderBox).constraints.pa
    if (iconLeftPadding + firstChild!.size.width + spaceBetween > offset2X)
      offset2X = iconLeftPadding + firstChild!.size.width + spaceBetween;
    data = firstChild?.parentData as _BranchComponentParentData;
    data.offset = Offset(iconLeftPadding, offset1Y);
    data = lastChild?.parentData as _BranchComponentParentData;
    data.offset = Offset(offset2X, offset2Y);
    // super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final parentData1 = firstChild?.parentData as BoxParentData;
    final parentData2 = lastChild?.parentData as BoxParentData;
    var off = parentData1.offset;
    context.paintChild(firstChild!, offset + off);
    context.paintChild(lastChild!, offset + parentData2.offset);
    // super.paint(context, offset);
  }
}
