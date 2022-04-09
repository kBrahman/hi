// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../util/util.dart';

enum SignalingState { CallStateBye, ConnectionOpen, ConnectionClosed, ConnectionError, NoInet }

/*
 * callbacks for Signaling API.
 */
typedef SignalingStateCallback = void Function(SignalingState state);
typedef StreamStateCallback = void Function(MediaStream stream);
typedef OtherEventCallback = void Function(dynamic event);
typedef DataChannelMessageCallback = void Function(RTCDataChannel dc, RTCDataChannelMessage data);
typedef DataChannelCallback = void Function(RTCDataChannel? dc);

class Signaling {
  static const TAG = 'Hi_Signaling';

  final _oldPeerIds = [];

  final String _selfId = randomNumeric(6);
  WebSocket? _socket;
  var _host;
  final _port = 4443;
  RTCPeerConnection? _peerConnection;
  final _dataChannels = <String, RTCDataChannel?>{};

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  SignalingStateCallback? onStateChange;
  late StreamStateCallback onLocalStream;
  late StreamStateCallback onRemoteStream;
  late StreamStateCallback onRemoveRemoteStream;
  DataChannelMessageCallback? onDataChannelMessage;
  DataChannelCallback? _onDataChannel;

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [],
  };

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
  String? localMC;
  String? peerId;
  final String turnServer;
  final String turnUname;
  final String turnPass;
  final decoder = const JsonDecoder();
  final encoder = const JsonEncoder();

  var candidateBuffer = [];

  Signaling(this._host, this.turnServer, this.turnUname, this.turnPass);

  close() {
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.close();
    _socket?.close();
    _socket = null;
  }

  isClosed() => _socket == null;

  void switchCamera() {
    var videoTrack = _localStream?.getVideoTracks().firstWhere((track) => track.kind == 'video');
    if (videoTrack != null) Helper.switchCamera(videoTrack);
  }

  void invite(peerId, String media, String remoteMC, useScreen) async {
    if (peerId == null) return;
    _peerConnection = await _createPeerConnection(peerId, media, remoteMC, useScreen);
    if (media == 'data') {
      _createDataChannel(peerId, _peerConnection);
    }
    _createOffer(peerId, _peerConnection, media, localMC);
  }

  void bye(bool isBusy) {
    _send('bye', <String, dynamic>{
      'to': peerId,
      'is_busy': isBusy,
    });
    if (peerId != null) {
      _oldPeerIds.add(peerId);
      peerId = null;
    }
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];
    var type = mapData['type'];
    switch (type) {
      case 'peer':
        invite(data['id'], 'video', data['mc'], false);
        break;
      case 'offer':
        {
          peerId = data['from'];
          hiLog(TAG, 'offer from =>$peerId');
          var description = data['description'];
          var media = data['media'];
          final remoteMC = data['mc'];
          _peerConnection = await _createPeerConnection(peerId, media, remoteMC, false);
          var sdp = description['sdp'];
          if (_peerConnection == null) {
            bye(false);
            break;
          }
          if (candidateBuffer.isNotEmpty) for (var c in candidateBuffer) await _peerConnection!.addCandidate(c);
          candidateBuffer.clear();
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, description['type']));
          await _createAnswer(peerId, _peerConnection!, media);
        }
        break;
      case 'answer':
        {
          var description = data['description'];
          peerId = data['from'];
          await _peerConnection?.setRemoteDescription(RTCSessionDescription(description['sdp'], description['type']));
        }
        break;
      case 'candidate':
        {
          var candidateMap = data['candidate'];
          hiLog(TAG, 'candimap=>$candidateMap');
          RTCIceCandidate candidate =
              RTCIceCandidate(candidateMap['candidate'], candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
          if (_peerConnection != null)
            _peerConnection?.addCandidate(candidate);
          else
            candidateBuffer.add(candidate);
        }
        break;
      case 'leave':
        {
          var id = data;
          _localStream?.dispose();
          _localStream = null;
          _peerConnection?.close();
          _dataChannels.remove(id);
          onStateChange?.call(SignalingState.CallStateBye);
        }
        break;
      case 'bye':
        {
          _localStream?.dispose();
          _remoteStream?.dispose();
          _peerConnection?.close();
          // var dc = _dataChannels[to];
          // if (dc != null) {
          // dc.close();
          // _dataChannels.remove(to);
          // }
          if (peerId != null) {
            _oldPeerIds.add(peerId);
            peerId = null;
          }
          onStateChange?.call(SignalingState.CallStateBye);
        }
        break;
      case 'keepalive':
        {
          print('keepalive response!');
        }
        break;
      default:
        break;
    }
  }

  Future<WebSocket> _connectForSelfSignedCert(String host, int port) async {
    try {
      Random r = Random();
      String key = base64.encode(List<int>.generate(8, (_) => r.nextInt(255)));
      SecurityContext securityContext = SecurityContext();
      HttpClient client = HttpClient(context: securityContext);
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        hiLog(TAG, 'bad cert=>$cert');
        return true;
      };

      HttpClientRequest request = await client.getUrl(Uri.parse('https://$host:$port/ws')); // form the correct url here
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('Sec-WebSocket-Version', '13'); // insert the correct version here
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase());

      HttpClientResponse response = await request.close();
      print('reasonPhrase=>${response.reasonPhrase}');
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

  void connect(String? model, String localMC, String? version) async {
    this.localMC = localMC;
    try {
      _socket = await _connectForSelfSignedCert(_host, _port);
      if (_socket == null) {
        onStateChange?.call(SignalingState.ConnectionError);
        return;
      }
      onStateChange?.call(SignalingState.ConnectionOpen);
      _socket!.listen((data) {
        onMessage(decoder.convert(data));
      }, onDone: () {
        onStateChange?.call(SignalingState.ConnectionClosed);
      });
      msgNew(model, localMC, version);
    } catch (e) {
      hiLog(TAG, 'exception=>$e');
      var code = (e as SocketException).osError?.errorCode;
      onStateChange?.call(code == 101 ? SignalingState.NoInet : SignalingState.ConnectionError);
    }
  }

  void msgNew(String? deviceInfo, String mediaConstraints, String? version) =>
      _send('new', {'d': deviceInfo, 'v': version, 'id': _selfId, 'mc': mediaConstraints, 'oldPeerIds': _oldPeerIds});

  Future<MediaStream> createStream(media, String? mc, userScreen) async {
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
    MediaStream stream = userScreen
        ? await navigator.mediaDevices.getDisplayMedia(remoteConstrains)
        : await navigator.mediaDevices.getUserMedia(remoteConstrains);
    return stream;
  }

  _createPeerConnection(id, media, String mc, userScreen) async {
    hiLog(TAG, 'creating peer connection');
    final _iceServers = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
        {'url': 'stun:stun2.l.google.com:19302'},
        {'url': 'stun:stun.ekiga.net'},
        {'url': turnServer, 'credential': turnPass, 'username': turnUname}
      ],
      'sdpSemantics': 'unified-plan'
    };
    RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);
    if (media != 'data') {
      _localStream = await createStream(media, mc, userScreen);
      _localStream?.getTracks().forEach((track) => pc.addTrack(track, _localStream!));
      onLocalStream(_localStream!);
    }
    pc.onIceCandidate = (candidate) {
      hiLog(TAG, 'on ice candidate=>${candidate.candidate}');
      _send('candidate', {
        'to': id,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        }
      });
    };
    pc.onTrack = (RTCTrackEvent event) {
      hiLog(TAG, 'onTrack=>${event.track.kind}');
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        var streams = event.streams;
        for (var element in streams) {
          hiLog(TAG, element.getVideoTracks().toString());
        }
        var stream = streams[0];
        onRemoteStream(stream);
        _remoteStream = stream;
      }
    };
    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream(stream);
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(id, channel);
    };
    return pc;
  }

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

  _createOffer(String id, RTCPeerConnection? pc, String media, String? localMC) async {
    try {
      RTCSessionDescription? s = await pc?.createOffer(media == 'data' ? _dcConstraints : _constraints);
      pc?.setLocalDescription(s!);
      _send('offer', {
        'to': id,
        'description': {'sdp': s?.sdp, 'type': s?.type},
        'media': media,
        'mc': localMC
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _createAnswer(String? id, RTCPeerConnection pc, media) async {
    hiLog(TAG, 'creating answer');
    try {
      RTCSessionDescription s = await pc.createAnswer(media == 'data' ? _dcConstraints : _constraints);
      pc.setLocalDescription(s);
      hiLog(TAG, 'sdp type=>${s.type}');
      _send('answer', {
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
      });
    } catch (e) {
      hiLog(TAG, e.toString());
    }
  }

  _send(event, data) {
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
}
