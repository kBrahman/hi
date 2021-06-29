import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../util/util.dart';

enum SignalingState {
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
  CallStateInCall,
  NoInet,
}

/*
 * callbacks for Signaling API.
 */
typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(
    RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(RTCDataChannel? dc);

class Signaling {
  static const TAG = 'Hi_Signaling';

  final _oldPeerIds = [];

  String _selfId = randomNumeric(6);
  WebSocket? _socket;
  var _host;
  var _port = 4443;
  RTCPeerConnection? _peerConnection;
  var _dataChannels = new Map<String, RTCDataChannel?>();

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  SignalingStateCallback? onStateChange;
  StreamStateCallback? onLocalStream;
  StreamStateCallback? onAddRemoteStream;
  StreamStateCallback? onRemoveRemoteStream;
  DataChannelMessageCallback? onDataChannelMessage;
  DataChannelCallback? onDataChannel;

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      {'url': 'stun:stun1.l.google.com:19302'},
      {'url': 'stun:stun2.l.google.com:19302'},
      {'url': 'stun:stun.ekiga.net'}
    ],
    'sdpSemantics': 'unified-plan'
  };

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
  var peerId;

  Signaling(this._host);

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
    var videoTrack = _localStream?.getVideoTracks()[0];
    if (videoTrack != null) Helper.switchCamera(videoTrack);
  }

  void invite(peerId, String media, String remoteMC, useScreen) async {
    if (peerId == null) return;
    _peerConnection =
        await _createPeerConnection(peerId, media, remoteMC, useScreen);
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
        {
          invite(data['id'], 'video', data['mc'], false);
        }
        break;
      case 'offer':
        {
          peerId = data['from'];
          hiLog(TAG, 'offer from =>$peerId');
          var description = data['description'];
          var media = data['media'];
          final remoteMC = data['mc'];
          _peerConnection =
              await _createPeerConnection(peerId, media, remoteMC, false);
          var sdp = description['sdp'];
          await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(sdp, description['type']));
          await _createAnswer(peerId, _peerConnection, media);
          this.onStateChange?.call(SignalingState.CallStateInCall);
        }
        break;
      case 'answer':
        {
          var description = data['description'];
          peerId = data['from'];
          await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
          this.onStateChange?.call(SignalingState.CallStateInCall);
        }
        break;
      case 'candidate':
        {
          var candidateMap = data['candidate'];
          RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'],
              candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
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
          this.onStateChange?.call(SignalingState.CallStateBye);
        }
        break;
      case 'bye':
        {
          _localStream?.dispose();
          _remoteStream?.dispose();
          _peerConnection?.close();
          _peerConnection = null;
          // var dc = _dataChannels[to];
          // if (dc != null) {
          // dc.close();
          // _dataChannels.remove(to);
          // }
          if (peerId != null) {
            _oldPeerIds.add(peerId);
            peerId = null;
          }
          this.onStateChange?.call(SignalingState.CallStateBye);
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
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return true;
      };

      HttpClientRequest request = await client.getUrl(
          Uri.parse('https://$host:$port/ws')); // form the correct url here
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add(
          'Sec-WebSocket-Version', '13'); // insert the correct version here
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase());

      HttpClientResponse response = await request.close();
      print(response.reasonPhrase);
      Socket socket = await response.detachSocket();
      // socket.close();
      var webSocket = WebSocket.fromUpgradedSocket(
        socket,
        protocol: 'signaling',
        serverSide: false,
      );
      return webSocket;
    } catch (e) {
      throw e;
    }
  }

  void connect(String? model, String localMC, String? version) async {
    this.localMC = localMC;
    try {
      _socket = await _connectForSelfSignedCert(_host, _port);
      this.onStateChange?.call(SignalingState.ConnectionOpen);

      _socket?.listen((data) {
        JsonDecoder decoder = JsonDecoder();
        this.onMessage(decoder.convert(data));
      }, onDone: () {
        this.onStateChange?.call(SignalingState.ConnectionClosed);
      });
      msgNew(model, localMC, version);
    } catch (e) {
      hiLog(TAG, 'exception=>$e');
      var code = (e as SocketException).osError?.errorCode;
      this.onStateChange?.call(
          code == 101 ? SignalingState.NoInet : SignalingState.ConnectionError);
    }
  }

  void msgNew(String? deviceInfo, String mediaConstraints, String? version) =>
      _send('new', {
        'd': deviceInfo,
        'v': version,
        'id': _selfId,
        'mc': mediaConstraints,
        'oldPeerIds': _oldPeerIds
      });

  Future<MediaStream> createStream(media, String? mc, userScreen) async {
    final cams = await availableCameras();
    hiLog(TAG, 'mc=>$mc; num of cams=>${cams.length}');
    var remoteConstrains = {
      'audio': true,
      'video': mc == null
          ? true
          : {
              'mandatory': {
                // 'minWidth': 100,
                'minWidth': mc.split(':').last.replaceAll(RegExp(r'\..+'), ''),
                // 'minHeight': 100,
                'minHeight':
                    mc.split(':').first.replaceAll(RegExp(r'\..+'), ''),
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
    RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);
    if (media != 'data') {
      _localStream = await createStream(media, mc, userScreen);
      _localStream
          ?.getTracks()
          .forEach((track) => pc.addTrack(track, _localStream!));
      hiLog(TAG, 'onLocalStream is null=>${onLocalStream == null}');
      this.onLocalStream!(_localStream!);
    }
    pc.onIceCandidate = (candidate) {
      _send('candidate', {
        'to': id,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMlineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        }
      });
    };
    pc.onTrack = (RTCTrackEvent event) {
      hiLog(TAG, 'onTrack=>${event.track.label}');
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        var stream = event.streams[0];
        this.onAddRemoteStream?.call(stream);
        _remoteStream = stream;
      }
    };
    pc.onRemoveStream = (stream) {
      this.onRemoveRemoteStream?.call(stream);
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(id, channel);
    };
    return pc;
  }

  _addDataChannel(id, RTCDataChannel? channel) {
    channel?.onDataChannelState = (e) {};
    channel?.onMessage = (RTCDataChannelMessage data) {
      this.onDataChannelMessage?.call(channel, data);
    };
    _dataChannels[id] = channel;
    this.onDataChannel?.call(channel);
  }

  _createDataChannel(id, RTCPeerConnection? pc, {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
    RTCDataChannel? channel =
        await pc?.createDataChannel(label, dataChannelDict);
    _addDataChannel(id, channel);
  }

  _createOffer(
      String id, RTCPeerConnection? pc, String media, String? localMC) async {
    try {
      RTCSessionDescription? s = await pc
          ?.createOffer(media == 'data' ? _dcConstraints : _constraints);
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

  _createAnswer(String id, RTCPeerConnection? pc, media) async {
    hiLog(TAG, 'creating answer');
    try {
      RTCSessionDescription? s = await pc
          ?.createAnswer(media == 'data' ? _dcConstraints : _constraints);
      pc?.setLocalDescription(s!);
      _send('answer', {
        'to': id,
        'description': {'sdp': s?.sdp, 'type': s?.type},
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _send(event, data) {
    data['type'] = event;
    JsonEncoder encoder = new JsonEncoder();
    if (_socket != null) _socket?.add(encoder.convert(data));
  }

  void mute(bool micMuted) {
    _remoteStream?.getAudioTracks().forEach((element) {
      element.enabled = !micMuted;
    });
  }

  bool hasFrontCamera(List<CameraDescription> cams) {
    for (final cd in cams) {
      hiLog(TAG, "cd=>$cd");
      if (cd.lensDirection == CameraLensDirection.front) return true;
    }
    return false;
  }
}
