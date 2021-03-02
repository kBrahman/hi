import 'dart:core';
import 'dart:io';

import 'package:admob_flutter/admob_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/call/call.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Admob.initialize();
  String data = await rootBundle.loadString('assets/local.properties');
  var iterable = data
      .split('\n')
      .where((element) => !element.startsWith('#') && element.isNotEmpty);
  var props = Map.fromIterable(iterable,
      key: (v) => v.split('=')[0], value: (v) => v.split('=')[1]);
  var s = props['server'];
  if (Platform.isIOS) {
    await Admob.requestTrackingAuthorization();
  }
  await [
    Permission.camera,
    Permission.microphone,
  ].request().then((statuses) => statuses.values.any((e) => !e.isGranted)
      ? exit(0)
      : runApp(new Call(ip: s)));
  // Future.wait([Permission.camera.status, Permission.microphone.status])
  //     .then((statuses) {
  //   print('statuses=>$statuses');
  //   runApp(StartWidget(s, statuses));
  // });
}

// class StartWidget extends StatefulWidget {
//   final ip;
//
//   final List<PermissionStatus> statuses;
//
//   StartWidget(this.ip, this.statuses);
//
//   @override
//   State<StatefulWidget> createState() => StartState();
// }

// class StartState extends State<StartWidget> {
//   var uiState;
//   List<String> restricted;
//
//   @override
//   void initState() {
//     if (widget.statuses.every((element) => element.isUndetermined)) {
//       uiState = PermissionStatus.undetermined;
//     } else if (widget.statuses.every((element) => element.isGranted)) {
//       uiState = PermissionStatus.granted;
//     } else if (widget.statuses
//         .any((element) => element.isDenied || element.isPermanentlyDenied)) {
//       uiState = PermissionStatus.denied;
//       // restricted =
//     }
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) => MaterialApp(
//         localizationsDelegates: [
//           GlobalMaterialLocalizations.delegate,
//           GlobalWidgetsLocalizations.delegate,
//           GlobalCupertinoLocalizations.delegate,
//           AppLocalizations.delegate
//         ],
//         supportedLocales: [
//           const Locale('en', ''),
//           const Locale('hi', ''),
//         ],
//         theme: ThemeData(
//           primarySwatch: MaterialColor(0xFFE10A50, colorCodes),
//           visualDensity: VisualDensity.adaptivePlatformDensity,
//         ),
//         home: Scaffold(
//           appBar: AppBar(
//             title: Text('hi'),
//           ),
//           body: Padding(
//             padding: EdgeInsets.all(4),
//             child: uiState == PermissionStatus.undetermined
//                 ? Column(
//                     children: [
//                       Text(
//                         'The core functionality of this app is based on video and audio streaming. For this reason it needs your explicit permission to use '
//                         'Camera and Microphone',
//                         style: TextStyle(fontSize: 30),
//                       ),
//                       Spacer(),
//                       Padding(
//                         padding: EdgeInsets.only(bottom: 8),
//                         child: TextButton(
//                           onPressed: () {
//                             [Permission.camera, Permission.microphone]
//                                 .request()
//                                 .then((statuses) => setState(() {
//                                       // granted = !statuses.values.any((e) => !e.isGranted);
//                                     }));
//                           },
//                           child: Text(
//                             'OK',
//                             style: TextStyle(color: Colors.white),
//                           ),
//                           style: ButtonStyle(
//                               backgroundColor: MaterialStateProperty.all(
//                                   Color.fromRGBO(211, 10, 75, 1))),
//                         ),
//                       )
//                     ],
//                   )
//                 : uiState == PermissionStatus.granted
//                     ? Call(ip: widget.ip)
//                     : Column(
//                         children: [
//                           Text(
//                             'It looks like you have denied' + getStatus(),
//                             style: TextStyle(fontSize: 30),
//                           ),
//                           Spacer(),
//                           Padding(
//                             padding: EdgeInsets.only(bottom: 8),
//                             child: TextButton(
//                               onPressed: () {
//                                 [Permission.camera, Permission.microphone]
//                                     .request()
//                                     .then((statuses) => setState(() {
//                                           // granted = !statuses.values.any((e) => !e.isGranted);
//                                         }));
//                               },
//                               child: Text(
//                                 'OK',
//                                 style: TextStyle(color: Colors.white),
//                               ),
//                               style: ButtonStyle(
//                                   backgroundColor: MaterialStateProperty.all(
//                                       Color.fromRGBO(211, 10, 75, 1))),
//                             ),
//                           )
//                         ],
//                       ),
//           ),
//         ),
//       );
//
//   String getStatus() {}
// }
