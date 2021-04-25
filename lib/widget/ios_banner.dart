import 'package:flutter/cupertino.dart';

class IosBanner extends StatelessWidget {
  final Map<String, dynamic> creationParams = <String, dynamic>{};
  final String viewType = 'ios_banner';

  @override
  Widget build(BuildContext context) {
    return Container(child: UiKitView(viewType: viewType), width: 320, height: 250);
  }
}
