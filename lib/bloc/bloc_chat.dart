// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/bloc/bloc_base.dart';
import 'package:hi/util/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatBloc extends BaseBloc<ChatData, Command> {
  static const _TAG = 'ChatBloc';
  static const NEW = 'new';
  static const TYPE = 'type';
  static const NEXT = 'next';
  static const MODEL = 'model';
  static const VERSION = 'version';
  static const CODE = 'code';
  static const ID = 'id';
  static const TO = 'to';
  static const FROM = 'from';
  static const DESC = 'desc';
  static const SDP = 'sdp';

  final remoteRenderer = RTCVideoRenderer()..initialize();
  final localRenderer = RTCVideoRenderer()..initialize();
  WebSocket? _socket;
  String? _peerId;
  RTCPeerConnection? pc;
  late RTCSessionDescription _offer;
  var _showingDialog = false;
  var _peerName = '';

  ChatBloc(String login, String name) {
    hiLog(_TAG, 'login:$login');
    _checkBlock(login);
    stream = _getStream(login, name);
  }

  void _checkBlock(String login) => SharedPreferences.getInstance()
      .then((sp) => isBlocked(login, sp))
      .then((blocked) => blocked ? ctr.add(Command.BLOCK_USER) : null);

  Stream<ChatData> _getStream(String login, String name) async* {
    String data = await rootBundle.loadString('assets/local.properties');
    final iterable = data.split('\n').where((element) => !element.startsWith('#') && element.isNotEmpty);
    final props = {for (final v in iterable) v.split('=')[0]: v.split('=')[1]};
    final String ip = props['server']!;
    WebSocket.connect('ws://$ip:4442/ws').then((s) => _onSocket(s, login, name, props)).onError((error, stackTrace) {
      hiLog(_TAG, 'connect, onError: $error');
      ctr.add(Command.MAINTENANCE);
    });
    var chatData = const ChatData();
    await for (final state in ctr.stream)
      switch (state) {
        case Command.DIALOG:
          _showingDialog = !_showingDialog;
          if (_peerId == null) {
            _socket?.add(jsonEncode({TYPE: NEXT}));
            yield chatData = chatData.copyWith(state: ChatState.WAITING);
          }
          break;
        case Command.REPORT:
          _showingDialog = false;
          _socket?.add(jsonEncode({TYPE: REPORT, TO: _peerId}));
          globalSink.add(GlobalEvent.REPORT_SENT);
          if (_peerId == null) {
            _socket?.add(jsonEncode({TYPE: NEXT}));
            yield chatData = chatData.copyWith(state: ChatState.WAITING);
          }
          break;
        case Command.BLOCK_PEER:
          _showingDialog = false;
          (await dbGlobal).insert(BLOCKED_PEER, {PEER_LOGIN: _peerId, NAME: _peerName, LOGIN: login});
          FirebaseFirestore.instance.doc('$USER/$login/$BLOCKED_PEER/$_peerId').set({NAME: _peerName});
          if (_peerId == null)
            _socket?.add(jsonEncode({TYPE: NEXT}));
          else
            _socket?.add(jsonEncode({TYPE: BYE, TO: _peerId}));
          yield chatData = chatData.copyWith(state: ChatState.WAITING);
          break;
        case Command.WAITING:
          yield chatData = chatData.copyWith(state: ChatState.WAITING);
          break;
        case Command.UPDATE:
          yield chatData = chatData.copyWith(state: ChatState.UPDATE);
          break;
        case Command.MAINTENANCE:
          yield chatData = chatData.copyWith(state: ChatState.MAINTENANCE);
          break;
        case Command.IN_CALL:
          yield chatData = chatData.copyWith(state: ChatState.IN_CALL);
          break;
        case Command.NEXT:
          pc?.dispose();
          _socket?.add(jsonEncode({TYPE: BYE, FROM: login, TO: _peerId}));
          yield chatData = chatData.copyWith(state: ChatState.WAITING);
          break;
        case Command.MUTE:
          final audioTrack = localRenderer.srcObject?.getAudioTracks()[0];
          audioTrack?.enabled = !audioTrack.enabled;
          yield chatData = chatData.copyWith(muted: audioTrack?.enabled == false);
          break;
        case Command.BLOCK_USER:
          yield chatData = chatData.copyWith(blocked: true);
          break;
        default:
          yield chatData;
      }
  }

  _onSocket(WebSocket socket, login, name, Map<String, String> props) async {
    _socket = socket;
    navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'}
    }).then((s) => _onLocalStream(s, socket, login, name, props));
  }

  Future<void> _sendOffer(WebSocket socket, RTCSessionDescription offer, peerId, name) async {
    final msgToSend = {TYPE: OFFER, TO: peerId, DESC: offer.toMap(), NAME: name};
    socket.add(jsonEncode(msgToSend));
  }

  Future<RTCPeerConnection> _createPC(Map<String, String> props) async {
    final turnServers = props['turnServers']!.split(':').map((e) => 'turn:$e:3478');
    final turnUname = props['turnUname']!;
    final turnPass = props['turnPass']!;
    hiLog(_TAG, 'turnUname:$turnUname, turnPass:$turnPass, turnServers:$turnServers');
    return await createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun1.l.google.com:19302'},
        {'url': 'stun:stun.ekiga.net'},
        ...turnServers.map((e) => {'url': e, 'credential': turnPass, 'username': turnUname}),
      ],
      'sdpSemantics': 'unified-plan'
    }, {
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      'optional': []
    })
      ..onIceCandidate = (candidate) {
        _socket?.add(jsonEncode({TYPE: CANDIDATE, CANDIDATE: candidate.toMap(), TO: _peerId}));
      }
      ..onTrack = (t) {
        hiLog(_TAG, 'onTrack');
        if (t.track.kind == 'video') {
          remoteRenderer.srcObject = t.streams.single;
        }
      }
      ..onConnectionState = (state) {
        hiLog(_TAG, 'onConnectionState: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          ctr.add(Command.IN_CALL);
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          pc?.restartIce();
          hiLog(_TAG, 'restarted ice');
        }
      };
  }

  Future<void> _sendAnswer(WebSocket socket, answer, myName) async {
    final msgToSend = {TYPE: ANSWER, TO: _peerId, DESC: answer.toMap(), NAME: myName};
    socket.add(jsonEncode(msgToSend));
  }

  dispose() {
    hiLog(_TAG, 'dispose');
    _socket?.close();
    platform.invokeMethod('isLoaded').then((value) => {if (value) platform.invokeMethod('show')});
  }

  _onData(data, WebSocket socket, props, MediaStream mediaStream, myName, Set<String> reports, login) async {
    hiLog(_TAG, 'socket event:$data');
    final msg = jsonDecode(data);
    switch (msg[TYPE]) {
      case REPORT:
        final added = reports.add(_peerId!);
        if (reports.length > 15)
          _block(login, reports);
        else if (added) {
          (await dbGlobal).insert(REPORT, {PEER_LOGIN: _peerId, LOGIN: login});
          FirebaseFirestore.instance.doc('$USER/$login').update({
            REPORT: FieldValue.arrayUnion([_peerId])
          });
        }
        break;
      case PEER:
        final peerId = msg[ID];
        pc = await _createPC(props);
        mediaStream.getTracks().forEach((t) => pc!.addTrack(t, mediaStream));
        _offer = await pc!.createOffer();
        _sendOffer(socket, _offer, peerId, myName);
        hiLog(_TAG, 'on peer:$peerId');
        break;
      case OFFER:
        hiLog(_TAG, 'on offer');
        _peerId = msg[FROM];
        _peerName = msg[NAME];
        final offerDesc = msg[DESC][SDP];
        await pc?.dispose();
        pc = await _createPC(props);
        pc!.setRemoteDescription(RTCSessionDescription(offerDesc, msg[DESC][TYPE]));
        mediaStream.getTracks().forEach((t) => pc!.addTrack(t, mediaStream));
        final answer = await pc!.createAnswer();
        pc!.setLocalDescription(answer);
        _sendAnswer(socket, answer, myName);
        break;
      case ANSWER:
        _peerId = msg[FROM];
        _peerName = msg[NAME];
        hiLog(_TAG, 'on answer');
        pc!.setLocalDescription(_offer);
        pc?.setRemoteDescription(RTCSessionDescription(msg[DESC][SDP], msg[DESC][TYPE]));
        break;
      case UPDATE:
        ctr.add(Command.UPDATE);
        break;
      case CANDIDATE:
        final candidateMap = msg[CANDIDATE];
        pc?.addCandidate(RTCIceCandidate(candidateMap['candidate'], candidateMap['sdpMid'], candidateMap['sdpMLineIndex']));
        break;
      case BYE:
        hiLog(_TAG, 'bye from:$_peerId');
        pc?.dispose();
        _checkBlock(login);
        _peerId = null;
        if (_showingDialog) return;
        socket.add(jsonEncode({TYPE: NEXT}));
        ctr.add(Command.WAITING);
    }
  }

  void descPrint(String desc) {
    final lines = desc.split('\r\n');
    lines.forEach(print);
  }

  _onLocalStream(MediaStream mediaStream, WebSocket socket, login, name, Map<String, String> props) async {
    final deviceInfo = await platform.invokeMethod('deviceInfo');
    final blockedPeers = (await (await dbGlobal).query(BLOCKED_PEER, where: '$LOGIN=?', whereArgs: [login]))
        .map((m) => m[PEER_LOGIN] as String)
        .toList();
    final msgNew = {
      TYPE: NEW,
      MODEL: deviceInfo[MODEL],
      'v': deviceInfo[VERSION],
      CODE: deviceInfo[CODE],
      ID: login,
      NAME: name,
      'blockedPeers': blockedPeers
    };
    final reports =
        (await (await dbGlobal).query(REPORT, where: '$LOGIN=?', whereArgs: [login])).map((m) => m[PEER_LOGIN] as String).toSet();
    socket.listen((data) => _onData(data, socket, props, mediaStream, name, reports, login), onDone: () {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      if (pc != null)
        pc!.dispose().whenComplete(mediaStream.dispose);
      else
        mediaStream.dispose();

      hiLog(_TAG, 'done, st:${FieldValue.serverTimestamp()}, ts:${DateTime.now().millisecondsSinceEpoch}');
    });
    FieldValue.serverTimestamp();
    socket.add(jsonEncode(msgNew));
    localRenderer.srcObject = mediaStream;
  }

  Future<void> _block(login, Set<String> reports) async {
    hiLog(_TAG, 'blocking, login:$login');
    (await dbGlobal).delete(REPORT, where: '$LOGIN=?', whereArgs: [login]);
    FirebaseFirestore.instance.doc('$USER/$login').update({REPORT: FieldValue.delete()}).catchError(onError);
    final doc = await FirebaseFirestore.instance.doc('$BLOCKED_USER/$login').get();
    var index = BlockPeriod.WEEK.index;
    if (doc.exists) {
      final cloudIndex = doc[BLOCK_PERIOD_INDEX];
      index = cloudIndex == BlockPeriod.FOREVER.index ? cloudIndex : cloudIndex + 1;
    }
    final ts = Timestamp.now();
    await FirebaseFirestore.instance.doc('$BLOCKED_USER/$login').set({BLOCK_TIME: ts, BLOCK_PERIOD_INDEX: index});
    final sp = await SharedPreferences.getInstance();
    Future.wait(
        [sp.setInt(BLOCK_TIME, ts.millisecondsSinceEpoch), sp.setInt(BLOCK_PERIOD_INDEX, index), sp.setBool(IS_BLOCKED, true)]);
    ctr.add(Command.BLOCK_USER);
  }

  void _del(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    hiLog(_TAG, 'deleting ${doc.id}');
    doc.reference.delete();
  }

  onError(e) {
    hiLog(_TAG, 'error deleting reports on cloud: $e');
  }
}

class ChatData {
  final ChatState state;
  final bool muted;
  final bool blocked;

  const ChatData({this.state = ChatState.WAITING, this.muted = false, this.blocked = false});

  ChatData copyWith({ChatState? state, bool? muted, bool? blocked}) =>
      ChatData(state: state ?? this.state, muted: muted ?? this.muted, blocked: blocked ?? this.blocked);
}

enum ChatState { WAITING, IN_CALL, MAINTENANCE, UPDATE, NEXT, MUTE }

enum Command { MUTE, NEXT, MAINTENANCE, IN_CALL, UPDATE, WAITING, DIALOG, BLOCK_PEER, REPORT, BLOCK_USER }
