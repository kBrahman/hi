// ignore_for_file: curly_braces_in_flow_control_structures, constant_identifier_names
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/bloc/bloc_profile.dart';
import 'package:hi/widget/widget_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/bloc_chat.dart';
import '../data/data_profile.dart';
import '../util/util.dart';

class ProfileWidget extends StatelessWidget {
  static const _TAG = 'ProfileWidget';
  static const RESULT_PERMANENTLY_DENIED = 2;
  static const RESULT_GRANTED = 3;
  static const RESULT_DENIED = 4;
  final ProfileBloc _profileBloc;

  const ProfileWidget(this._profileBloc, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const edgeInsetsTop16 = EdgeInsets.only(top: 16);
    final locs = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: const Text('hi'), actions: [
          IconButton(
              onPressed: () => SharedPreferences.getInstance()
                  .then((sp) => Future.wait([sp.remove(IS_SIGNED_IN), sp.remove(LOGIN), sp.remove(NAME)]))
                  .then((_) => _profileBloc.globalSink.add(GlobalEvent.SIGN_IN)),
              icon: const Icon(Icons.exit_to_app))
        ]),
        body: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<ProfileData>(
                stream: _profileBloc.stream,
                builder: (context, snap) {
                  final data = snap.data;
                  if (data == null) return const Center(child: CircularProgressIndicator());
                  hiLog(_TAG, 'data:$data');
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${locs?.logged_in_as ?? 'Logged in as:'} ${data.login}', style: const TextStyle(color: Colors.grey)),
                    Column(children: [
                      Row(children: [
                        Text('${locs?.name ?? 'Your name'}:', style: bold20),
                        Expanded(
                            child: Padding(
                                padding: edgeInsetsLR8,
                                child: TextField(style: const TextStyle(fontSize: 20), controller: _profileBloc.txtCtr)))
                      ]),
                      if (data.nameEmpty)
                        Text(locs?.name_enter ?? 'Enter your name please',
                            style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ]),
                    Padding(padding: edgeInsetsTop16, child: Text(locs?.blocked_users ?? 'Blocked users:', style: bold20)),
                    Expanded(
                        child: StreamBuilder<List<Map<String, Object?>>>(
                            stream: _profileBloc.blockedUsersStream,
                            initialData: const [],
                            builder: (context, snap) {
                              hiLog(_TAG, 'blockedUsers:${snap.data}');
                              return ListView(
                                  padding: const EdgeInsets.only(top: 4),
                                  children: snap.data!
                                      .map((m) => Dismissible(
                                          onDismissed: (d) {
                                            final peerLogin = m[PEER_LOGIN];
                                            hiLog(_TAG, 'on dismiss peerLogin:$peerLogin');
                                            _profileBloc.removeRefreshSink.add(peerLogin as String);
                                          },
                                          key: ValueKey(m[PEER_LOGIN]),
                                          child: Card(
                                              child: Padding(
                                                  padding: const EdgeInsets.only(left: 4, right: 4, top: 12, bottom: 12),
                                                  child: Text(m[NAME] as String, style: const TextStyle(fontSize: 25))))))
                                      .toList());
                            })),
                    Padding(
                        padding: edgeInsetsTop16,
                        child: Center(
                            child:
                                ElevatedButton(onPressed: () => _start(context, data), child: Text(locs?.start ?? 'START CHAT'))))
                  ]);
                })));
  }

  Future<void> _start(context, ProfileData data) async {
    if (_profileBloc.txtCtr.text.isEmpty)
      _profileBloc.ctr.add(ProfileCmd.NAME_EMPTY);
    else if (!BaseBloc.connectedToInet)
      _profileBloc.globalSink.add(GlobalEvent.NO_INTERNET);
    else {
      switch (await _profileBloc.platform.invokeMethod('requestPermissions')) {
        case RESULT_PERMANENTLY_DENIED:
          _profileBloc.globalSink.add(GlobalEvent.PERMISSION_PERMANENTLY_DENIED);
          break;
        case RESULT_GRANTED:
          hiLog(_TAG, '_start, login:${data.login}');
          final bloc = ChatBloc(data.login, _profileBloc.txtCtr.text);
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatWidget(bloc))).whenComplete(() {
            bloc.dispose();
            _profileBloc.removeRefreshSink.add(null);
          });
          _profileBloc.ctr.add(ProfileCmd.UPDATE);
          break;
        case RESULT_DENIED:
          _profileBloc.globalSink.add(GlobalEvent.PERMISSION_DENIED);
      }
    }
  }
}
