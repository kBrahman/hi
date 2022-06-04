// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/util/util.dart';
import 'package:sqflite/sqflite.dart';

enum SignalingState { CallStateBye, ConnectionOpen, ConnectionClosed, ConnectionError, NoInet, BLOCK }

/*
 * callbacks for Signaling API.
 */
typedef SignalingStateCallback = void Function(SignalingState state);
typedef StreamStateCallback = void Function(MediaStream _remoteStream, MediaStream _localStream);
typedef OtherEventCallback = void Function(dynamic event);
typedef DataChannelMessageCallback = void Function(RTCDataChannel dc, RTCDataChannelMessage data);
typedef DataChannelCallback = void Function(RTCDataChannel? dc);

class Signaling {
  static const TAG = 'Hi_Signaling';

  late List<String?> _oldPeerIds;

  final String _selfId;
  WebSocket? _socket;
  final String _ip;
  final _port = 4443;
  RTCPeerConnection? _peerConnection;
  final _dataChannels = <String, RTCDataChannel?>{};

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  late SignalingStateCallback onStateChange;
  late StreamStateCallback onStreams;
  late VoidCallback onRemoveRemoteStream;
  DataChannelMessageCallback? onDataChannelMessage;
  DataChannelCallback? _onDataChannel;

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };
  final String screenSize;
  String? _peerId;
  final String turnServer;
  final String turnUname;
  final String turnPass;
  final decoder = const JsonDecoder();
  final encoder = const JsonEncoder();
  late int lastIceCandidateTime;
  final String _version;
  final String model;
  late RTCSessionDescription _localDesc;
  int restartCount = 0;
  final Database _db;
  final String _selfName;
  late String _peerName;
  late List<String?> _reports;
  late int lastBlockedPeriod;

  Signaling(this._selfId, this._selfName, this._ip, this.turnServer, this.turnUname, this.turnPass, this.screenSize, this.model,
      this._version, this._db) {
    _db
        .query(BLOCKED_USER, columns: [BLOCKED_LOGIN], where: '$LOGIN=?', whereArgs: [_selfId])
        .then((bLogins) => _oldPeerIds = bLogins.map((uMap) => uMap[BLOCKED_LOGIN] as String).toList());
    _db
        .query(REPORT, columns: [REPORTER_LOGIN], where: '$LOGIN=?', whereArgs: [_selfId])
        .then((reporters) => reporters.map((r) => r[REPORTER_LOGIN] as String).toList())
        .then((mapped) {
      _reports = mapped;
      hiLog(TAG, 'got report from db=>$_reports');
    });
    _db.query(TABLE_USER,
        columns: [LAST_BLOCK_PERIOD]).then((value) => lastBlockedPeriod = value.first[LAST_BLOCK_PERIOD] as int);
  }

  close() {
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
  }

  disconnect() {
    _socket?.close();
    _socket = null;
  }

  isDisconnected() => _socket == null;

  void switchCamera() {
    var videoTrack = _localStream?.getVideoTracks().firstWhere((track) => track.kind == 'video');
    if (videoTrack != null) Helper.switchCamera(videoTrack);
  }

  void invite(peerId, mc) async {
    _peerConnection = await _createPeerConnection(mc);
    if (_peerConnection == null) {
      onStateChange(SignalingState.ConnectionError);
    } else {
      _localDesc = await _createOffer(_peerConnection);
      _offer(peerId, _localDesc, screenSize);
      hiLog(TAG, 'offer sent');
    }
  }

  void bye(bool busy, bool addToAld) {
    _send('bye', <String, dynamic>{
      'to': _peerId,
      'is_busy': busy,
    });
    if (_peerId != null && addToAld) _oldPeerIds.add(_peerId);
    _peerId = null;
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];
    var type = mapData['type'];
    switch (type) {
      case REPORT:
        if (_reports.length < 15) {
          _reports.add(_peerId);
          _db.insert(REPORT, {REPORTER_LOGIN: _peerId, LOGIN: _selfId});
          FirebaseFirestore.instance.doc('user/$_selfId/$REPORT/$_peerId').set({});
        } else {
          onStateChange(SignalingState.BLOCK);
          _db.update(TABLE_USER, {LAST_BLOCK_PERIOD: getBlockPeriod(lastBlockedPeriod)});
          _reports.forEach(delete);
          _reports.clear();
        }
        break;
      case PEER:
        _peerName = data[NAME] ?? 'unknown';
        invite(data['id'], data['mc']);
        break;
      case OFFER:
        _peerId = data['from'];
        hiLog(TAG, 'offer from $_peerId');
        final description = data['description'];
        _accept(description['sdp'], description['type'], _peerId!, data['mc']);
        break;
      case ANSWER:
        {
          final description = data['description'];
          _peerId = data['from'];
          await _peerConnection?.setLocalDescription(_localDesc);
          await _peerConnection?.setRemoteDescription(RTCSessionDescription(description['sdp'], description['type']));
        }
        break;
      case 'candidate':
        {
          var candidateMap = data['candidate'];
          hiLog(TAG, 'remote candidate=>$candidateMap');
          RTCIceCandidate candidate =
              RTCIceCandidate(candidateMap['candidate'], candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
          _peerConnection?.addCandidate(candidate);
        }
        break;
      case 'leave':
        {
          var id = data;
          _localStream?.dispose();
          _localStream = null;
          _peerConnection?.close();
          _dataChannels.remove(id);
          onStateChange(SignalingState.CallStateBye);
        }
        break;
      case 'bye':
        {
          _localStream?.dispose();
          _remoteStream?.dispose();
          _peerConnection?.close();
          if (_peerId != null) _oldPeerIds.add(_peerId);
          _peerId = null;
          hiLog(TAG, 'received bye');
          onStateChange(SignalingState.CallStateBye);
        }
        break;
      case 'keepalive':
        {
          print('keepalive response!');
        }
        break;
    }
  }

  _accept(sdp, type, String id, mc) async {
    _peerConnection = await _createPeerConnection(mc);
    if (_peerConnection == null) {
      bye(false, false);
      return;
    }
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _localDesc = await _createAnswer(_peerConnection!);
    await _peerConnection!.setLocalDescription(_localDesc);
    _answer(id, _localDesc);
  }

  Future<WebSocket> _connectForSelfSignedCert(String ip, int port) async {
    try {
      Random r = Random();
      String key = base64.encode(List<int>.generate(8, (_) => r.nextInt(255)));
      SecurityContext securityContext = SecurityContext();
      HttpClient client = HttpClient(context: securityContext);
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

      HttpClientRequest request = await client.getUrl(Uri.parse('https://$ip:$port/ws')); // form the correct url here
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('Sec-WebSocket-Version', '13'); // insert the correct version here
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase());

      HttpClientResponse response = await request.close();
      Socket socket = await response.detachSocket();
      // socket.close();
      var webSocket = WebSocket.fromUpgradedSocket(
        socket,
        protocol: 'signaling',
        serverSide: false,
      );
      return webSocket;
    } catch (e) {
      rethrow;
    }
  }

  void connect() async {
    try {
      _socket = await _connectForSelfSignedCert(_ip, _port);
      if (_socket == null) {
        onStateChange(SignalingState.ConnectionError);
        return;
      }
      onStateChange(SignalingState.ConnectionOpen);
      _socket!.listen((data) {
        onMessage(decoder.convert(data));
      }, onDone: () {
        onStateChange(SignalingState.ConnectionClosed);
      });
      msgNew();
    } catch (e) {
      hiLog(TAG, 'exception=>$e');
      var code = (e as SocketException).osError?.errorCode;
      onStateChange(code == 101 ? SignalingState.NoInet : SignalingState.ConnectionError);
    }
  }

  void msgNew() =>
      _send('new', {'d': model, 'v': _version, 'id': _selfId, 'name': _selfName, 'mc': screenSize, 'oldPeerIds': _oldPeerIds});

  Future<MediaStream> _createStream(String? mc) async {
    final cams = await availableCameras();
    var remoteConstrains = {
      'audio': true,
      'video': mc == null
          ? true
          : {
              'mandatory': {
                'minWidth': mc.split(':').last.replaceAll(RegExp(r'\..+'), ''),
                'minHeight': mc.split(':').first.replaceAll(RegExp(r'\..+'), ''),
                'minFrameRate': '20',
              },
              'facingMode': hasFrontCamera(cams) ? 'user' : 'environment'
              //   'optional': [],
            }
    };
    return await navigator.mediaDevices.getUserMedia(remoteConstrains);
  }

  Future<RTCPeerConnection> _createPeerConnection(mc) async {
    hiLog(TAG, 'creating peer connection');
    final _iceServers = {
      'iceServers': [
        {'url': 'stun:stun1.l.google.com:19302'},
        {'url': 'stun:stun.ekiga.net'},
        {'url': turnServer, 'credential': turnPass, 'username': turnUname}
      ],
      'sdpSemantics': 'unified-plan'
    };
    _localStream = await _createStream(mc);
    final pc = await createPeerConnection(_iceServers, _constraints)
      ..onTrack = (RTCTrackEvent event) {
        hiLog(TAG, 'onTrack=>${event.track.kind}');
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          var streams = event.streams;
          var stream = streams[0];
          _remoteStream = stream;
        }
      }
      ..onIceCandidate = (candidate) {
        hiLog(TAG, 'on ice candidate=>${candidate.candidate}');
        _sendCandidate(_peerId, candidate);
      }
      ..onRemoveStream = (stream) {
        onRemoveRemoteStream();
      }
      ..onDataChannel = (channel) {
        // _addDataChannel(id, channel);
      }
      ..onIceConnectionState = (s) {
        hiLog(TAG, 'onIceConnectionState=>$s');
        if (s == RTCIceConnectionState.RTCIceConnectionStateFailed) restartOrBye();
      }
      ..onConnectionState = (s) {
        hiLog(TAG, 'onConnectionState=>$s');
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected)
          onStreams(_remoteStream!, _localStream!);
        else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) restartOrBye();
      }
      ..onRenegotiationNeeded = () {
        hiLog(TAG, 'on negotiation needed');
      };
    _localStream?.getTracks().forEach((track) => pc.addTrack(track, _localStream!));
    return pc;
  }

  void restartOrBye() {
    hiLog(TAG, 'restartOrBye restart count=>$restartCount');
    if (restartCount++ < ICE_RESTART_COUNT_THRESHOLD)
      _peerConnection?.restartIce();
    else {
      restartCount = 0;
      bye(true, false);
      msgNew();
    }
  }

  void _sendCandidate(id, RTCIceCandidate candidate) => _send('candidate', {
        'to': id,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        }
      });

  _addDataChannel(id, RTCDataChannel? channel) {
    channel?.onDataChannelState = (e) {};
    channel?.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(channel, data);
    };
    _dataChannels[id] = channel;
    _onDataChannel?.call(channel);
  }

  _createDataChannel(id, RTCPeerConnection? pc, {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    RTCDataChannel? channel = await pc?.createDataChannel(label, dataChannelDict);
    _addDataChannel(id, channel);
  }

  _createOffer(RTCPeerConnection? pc) async {
    try {
      return await pc?.createOffer(_constraints);
    } catch (e) {
      rethrow;
    }
  }

  void _offer(id, RTCSessionDescription? desc, String? screenSize) => _send('offer', {
        'to': id,
        'description': {'sdp': desc?.sdp, 'type': desc?.type},
        'mc': screenSize
      });

  _createAnswer(RTCPeerConnection pc) async {
    hiLog(TAG, 'creating answer');
    try {
      return await pc.createAnswer(_constraints);
    } catch (e) {
      hiLog(TAG, e.toString());
    }
  }

  void _answer(String? id, RTCSessionDescription desc) => _send('answer', {
        'to': id,
        'description': {'sdp': desc.sdp, 'type': desc.type},
        'size': screenSize
      });

  void _send(event, data) {
    data['type'] = event;
    if (_socket != null) _socket?.add(encoder.convert(data));
  }

  void mute(bool micMuted) {
    _remoteStream?.getAudioTracks().forEach((element) {
      element.enabled = !micMuted;
    });
  }

  bool hasFrontCamera(List<CameraDescription> cams) {
    for (final cd in cams) if (cd.lensDirection == CameraLensDirection.front) return true;
    return false;
  }

  void block() {
    _oldPeerIds.add(_peerId);
    _db.insert(BLOCKED_USER, {BLOCKED_LOGIN: _peerId, NAME: _peerName, LOGIN: _selfId});
    FirebaseFirestore.instance.doc('user/$_selfId/$BLOCKED_USER/$_peerId').set({NAME: _peerName});
  }

  void report() => _send('report', {'to': _peerId});

  void delete(String? element) => FirebaseFirestore.instance.doc('user/$_selfId/$REPORT/$element').delete();

  int getBlockPeriod(int lastBlockedPeriod) => lastBlockedPeriod < BLOCK_YEAR ? lastBlockedPeriod + 1 : BLOCK_YEAR;
}
