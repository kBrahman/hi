// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hi/util/util.dart';
import 'package:sqflite/sqflite.dart';

enum SignalingState { CallStateBye, ConnectionOpen, ConnectionClosed, ConnectionError, NoInet, Block, Update }

/*
 * callbacks for Signaling API.
 */
typedef SignalingStateCallback = void Function(SignalingState state, [int lastBlockPeriod]);
typedef StreamStateCallback = void Function(MediaStream? _remoteStream, MediaStream _localStream);
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

  final String screenSize;
  String? _peerId;
  final Iterable<String> turnServers;
  final String turnUname;
  final String turnPass;
  final decoder = const JsonDecoder();
  final encoder = const JsonEncoder();
  late int lastIceCandidateTime;
  final String _version;
  final String model;
  late RTCSessionDescription _localDesc;
  int failCount = 0;
  final Database _db;
  final String _selfName;
  late String _peerName;
  late List<String?> _reports;
  late int lastBlockedPeriod;
  bool _connecting = false;
  _OfferTimeOutFuture? _future;
  var _closed = false;

  Signaling(this._selfId, this._selfName, this._ip, this.turnServers, this.turnUname, this.turnPass, this.screenSize, this.model,
      this._version, this._db) {}

  close() {
    _closed = true;
    _future?.cancelled = true;
    _peerConnection?.getLocalStreams().clear();
    _peerConnection?.getRemoteStreams().clear();
    _peerConnection?.dispose();
    _peerConnection?.close();
    _peerConnection?.onConnectionState = null;
    _peerConnection = null;
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _socket?.close();
    _socket = null;
    hiLog(TAG, 'close, _socket=>$_socket');
  }

  disconnect() {
    _socket?.close();
    _socket = null;
  }

  isDisconnected() => _socket == null;

  void invite(peerId, mc) async {
    hiLog(TAG, 'invite');
    _peerConnection = await _createPeerConnection(mc);
    if (_peerConnection == null)
      onStateChange(SignalingState.ConnectionError);
    else {
      _future?.cancelled = true;
      _localDesc = await _createOffer(_peerConnection);
      _offer(peerId, _localDesc, screenSize);
      _connecting = true;
      _future = _OfferTimeOutFuture(msgNew);
    }
  }

  void bye(bool busy, bool addToOld) {
    _send('bye', {'to': _peerId, 'is_busy': busy});
    if (_peerId != null && addToOld) _oldPeerIds.add(_peerId);
    _peerId = null;
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];
    var type = mapData['type'];
    switch (type) {
      case UPDATE:
        onStateChange(SignalingState.Update);
        break;
      case REPORT:
        if (_reports.length < 14) {
          _reports.add(_peerId);
          FirebaseFirestore.instance.doc('user/$_selfId/$REPORT/$_peerId').set({});
        } else {
          _reports.forEach(delete);
          _db.delete(REPORT, where: '$LOGIN=?', whereArgs: [_selfId]);
          _reports.clear();
          onStateChange(SignalingState.Block, lastBlockedPeriod);
        }
        break;
      case PEER:
        if (_socket == null) return;
        _peerName = data[NAME] ?? 'unknown';
        invite(data['id'], data['mc']);
        break;
      case OFFER:
        if (_socket == null) return;
        _peerId = data['from'];
        hiLog(TAG, 'offer from $_peerId');
        _connecting = true;
        final description = data['description'];
        _accept(description['sdp'], description['type'], _peerId!, data['mc']);
        break;
      case ANSWER:
        _future?.cancelled = true;
        _peerId = data['from'];
        hiLog(TAG, 'answer from=>$_peerId');
        if (_socket == null) {
          hiLog(TAG, 'received answer from $_peerId, but socket null, returning');
          return;
        }
        final description = data['description'];
        await _peerConnection?.setLocalDescription(_localDesc);
        await _peerConnection?.setRemoteDescription(RTCSessionDescription(description['sdp'], description['type']));
        hiLog(TAG, 'answer from=>$_peerId');
        break;
      case CANDIDATE:
        final candidateMap = data[CANDIDATE];
        hiLog(TAG, 'remote candidate=>$candidateMap');
        RTCIceCandidate candidate =
            RTCIceCandidate(candidateMap['candidate'], candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
        _peerConnection?.addCandidate(candidate);
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
          hiLog(TAG, 'received bye from=>$_peerId');
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
    hiLog(TAG, 'connect');
    _closed = false;
    try {
      _socket = await _connectForSelfSignedCert(_ip, _port);
      if (_closed) return;
      hiLog(TAG, 'created socket=>$_socket');
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
      final code = (e as SocketException).osError?.errorCode;
      onStateChange(code == 101 ? SignalingState.NoInet : SignalingState.ConnectionError);
    }
  }

  void msgNew() {
    _send('new', {'d': model, 'v': _version, 'id': _selfId, 'name': _selfName, 'mc': screenSize, 'oldPeerIds': _oldPeerIds});
    hiLog(TAG, 'msg new');
  }

  Future<MediaStream> _createStream(String? hw) async {
    final regExp = RegExp(r'\..+');
    final constraints = {
      'audio': true,
      'video': hw == null
          ? true
          : {
              'width': hw.split(':').last.replaceAll(regExp, ''),
              'height': hw.split(':').first.replaceAll(regExp, ''),
              'frameRate': '25',
              'facingMode': ['user', 'left', 'right'],
              'advanced': [
                {
                  'frameRate': {'min': 55}
                },
                {
                  'frameRate': {'min': 45}
                },
                {
                  'frameRate': {'min': 35}
                }
              ]

              //   'optional': [],
            }
    };
    final mediaDevices = navigator.mediaDevices;
    hiLog(TAG, 'supported constraints:${mediaDevices.getSupportedConstraints()}');
    return await mediaDevices.getUserMedia(constraints);
  }

  Future<RTCPeerConnection> _createPeerConnection(mc) async {
    hiLog(TAG, 'creating peer connection');
    final iceServers = {
      'iceServers': [
        {'url': 'stun:stun1.l.google.com:19302'},
        {'url': 'stun:stun.ekiga.net'},
        ...turnServers.map((e) => {'url': e, 'credential': turnPass, 'username': turnUname}),
      ],
      'sdpSemantics': 'unified-plan'
    };
    _localStream = await _createStream(mc);
    final pc = await createPeerConnection(iceServers, _constraints)
      ..onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          var streams = event.streams;
          var stream = streams[0];
          _remoteStream = stream;
          // _remoteStream?.getTracks().single

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
      ..onConnectionState = (s) {
        hiLog(TAG, 'onConnectionState=>$s, _socket=>$_socket');
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          onStreams(_remoteStream, _localStream!);
          _connecting = false;
        } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          failCount++;
          hiLog(TAG, 'fail count=>$failCount');
          if (failCount == 1)
            invite(_peerId, mc);
          else {
            _connecting = false;
            failCount = 0;
            close();
            connect();
          }
        }
      }
      ..onRenegotiationNeeded = () {
        hiLog(TAG, 'on renegotiation needed');
      };
    _localStream?.getTracks().forEach((track) => pc.addTrack(track, _localStream!));
    return pc;
  }

  void restartOrBye() {
    hiLog(TAG, 'restartOrBye restart count=>$failCount');
    if (++failCount < ICE_RESTART_COUNT_THRESHOLD)
      _peerConnection?.restartIce();
    else {
      hiLog(TAG, "threshold exceeded");
      _connecting = false;
      failCount = 0;
      close();
      connect();
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

  void block() {
    if (_peerId?.contains('@') == false) return;
    _oldPeerIds.add(_peerId);
    FirebaseFirestore.instance.doc('user/$_selfId/$BLOCKED_USER/$_peerId').set({NAME: _peerName});
  }

  void report() => _send('report', {'to': _peerId});

  void delete(String? element) => FirebaseFirestore.instance.doc('user/$_selfId/$REPORT/$element').delete();

  // int getBlockPeriod(int lastBlockedPeriod) => lastBlockedPeriod < BLOCK_YEAR ? lastBlockedPeriod + 1 : BLOCK_YEAR;

  bool isConnecting() => _connecting;
}

class _OfferTimeOutFuture {
  static const TAG = '_OfferTimeOutFuture';

  bool cancelled = false;
  final VoidCallback run;

  _OfferTimeOutFuture(this.run) {
    Future.delayed(const Duration(seconds: 19), () {
      if (!cancelled) {
        run();
        hiLog(TAG, 'run');
      }
    });
  }
}
