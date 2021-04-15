import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../util/util.dart';

enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
  NoInet,
}

/*
 * callbacks for Signaling API.
 */
typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(RTCDataChannel dc);

class Signaling {
  static const TAG = 'Signaling';

  final _oldPeerIds = [];

  String _selfId = randomNumeric(6);
  WebSocket? _socket;
  var _sessionId;
  var _host;
  var _port = 4443;
  RTCPeerConnection? _peerConnection;
  var _dataChannels = new Map<String, RTCDataChannel>();
  var _remoteCandidates = [];

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
      {'url': 'stun:stun1.l.google.com:19302'}
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

  Signaling(this._host);

  close() {
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    _peerConnection?.close();
    if (_socket != null) _socket?.close();
  }

  void switchCamera() {
    var videoTrack = _localStream?.getVideoTracks()[0];
    if (videoTrack != null) Helper.switchCamera(videoTrack);
  }

  void invite(peerId, String media, String remoteMC, useScreen) async {
    if (peerId == null) return;
    this._sessionId = this._selfId + "-" + peerId;
    final pc = await _createPeerConnection(peerId, media, remoteMC, useScreen);
    _peerConnection = pc;
    if (media == 'data') {
      _createDataChannel(peerId, pc);
    }
    _createOffer(peerId, pc, media, localMC);
  }

  void bye(bool isBusy) {
    _send('bye', <String, dynamic>{
      'session_id': this._sessionId,
      'is_busy': isBusy,
    });
  }

  void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];
    var type = mapData['type'];
    switch (type) {
      case 'peer':
        {
          log(TAG, 'on peer=>$data');
          invite(data['id'], 'video', data['mc'], false);
        }
        break;
      case 'offer':
        {
          var id = data['from'];
          var description = data['description'];
          var media = data['media'];
          var sessionId = data['session_id'];
          this._sessionId = sessionId;
          final remoteMC = data['mc'];

          this.onStateChange?.call(SignalingState.CallStateNew);

          var pc = await _createPeerConnection(id, media, remoteMC, false);
          _peerConnection = pc;
          var sdp = description['sdp'];
          print('sdp=>$sdp');
          await pc.setRemoteDescription(RTCSessionDescription(sdp, description['type']));
          await _createAnswer(id, pc, media);
          if (this._remoteCandidates.length > 0) {
            _remoteCandidates.forEach((candidate) async {
              await pc.addCandidate(candidate);
            });
            _remoteCandidates.clear();
          }
        }
        break;
      case 'answer':
        log(TAG, 'answer');
        {
          var description = data['description'];
          var pc = _peerConnection;
          if (pc != null) {
            await pc
                .setRemoteDescription(RTCSessionDescription(description['sdp'], description['type']));
          }
        }
        this.onStateChange?.call(SignalingState.CallStateNew);
        break;
      case 'candidate':
        {
          var candidateMap = data['candidate'];
          var pc = _peerConnection;
          RTCIceCandidate candidate = RTCIceCandidate(
              candidateMap['candidate'], candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
          if (pc != null) {
            await pc.addCandidate(candidate);
          } else {
            _remoteCandidates.add(candidate);
          }
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
          this._sessionId = null;
        }
        break;
      case 'bye':
        {
          var to = data['to'];
          var sessionId = data['session_id'];

          _localStream?.dispose();
          _localStream = null;

          var pc = _peerConnection;
          if (pc != null) {
            pc.close();
          }

          var dc = _dataChannels[to];
          if (dc != null) {
            dc.close();
            _dataChannels.remove(to);
          }

          this._sessionId = null;
          var onStateChangeIsNUll = this.onStateChange == null;
          if (!onStateChangeIsNUll) {
            addOldPeerId(sessionId);
            this.onStateChange?.call(SignalingState.CallStateBye);
          }
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

  void addOldPeerId(sessionId) {
    if (sessionId == null) return;
    var ids = sessionId.split('-');
    var oldId = ids[1];
    if (oldId == _selfId) oldId = ids[0];
    _oldPeerIds.add(oldId);
  }

  Future<WebSocket> _connectForSelfSignedCert(String host, int port) async {
    try {
      Random r = Random();
      String key = base64.encode(List<int>.generate(8, (_) => r.nextInt(255)));
      SecurityContext securityContext = SecurityContext();
      HttpClient client = HttpClient(context: securityContext);
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };

      HttpClientRequest request =
          await client.getUrl(Uri.parse('https://$host:$port/ws')); // form the correct url here
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('Sec-WebSocket-Version', '13'); // insert the correct version here
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

  void connect(String? model, String localMC) async {
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

      msgNew(model, localMC);
    } catch (e) {
      var code = (e as SocketException).osError?.errorCode;
      this.onStateChange?.call(code == 101 ? SignalingState.NoInet : SignalingState.ConnectionError);
    }
  }

  void msgNew(String? deviceInfo, String mediaConstraints) {
    print('msgNew');
    _send('new',
        {'devInfo': deviceInfo, 'id': _selfId, 'mc': mediaConstraints, 'oldPeerIds': _oldPeerIds});
  }

  Future<MediaStream> createStream(media, String? mc, userScreen) async {
    log(TAG, 'mc=>$mc');
    var remoteConstrains = {
      'audio': true,
      'video': mc == null
          ? true
          : {
              'mandatory': {
                // 'minWidth': 100,
                'minWidth': mc.split(':').last.replaceAll(RegExp(r'\..+'), ''),
                // 'minHeight': 100,
                'minHeight': mc.split(':').first.replaceAll(RegExp(r'\..+'), ''),
                'minFrameRate': '20',
              },
              'facingMode': 'user',
              //   'optional': [],
            }
    };
    MediaStream stream = userScreen
        ? await navigator.mediaDevices.getDisplayMedia(remoteConstrains)
        : await navigator.mediaDevices.getUserMedia(remoteConstrains);
    this.onLocalStream?.call(stream);
    return stream;
  }

  _createPeerConnection(id, media, String mc, userScreen) async {
    RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);
    if (media != 'data') {
      _localStream = await createStream(media, mc, userScreen);
      _localStream?.getTracks().forEach((track) => pc.addTrack(track, _localStream!));
    }
    pc.onIceCandidate = (candidate) {
      _send('candidate', {
        'to': id,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMlineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        },
        'session_id': this._sessionId,
      });
    };
    pc.onIceConnectionState = (state) {};
    pc.onTrack = (RTCTrackEvent event) {
      print('onTrack=>${event.track.label}');
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        var stream = event.streams[0];
        print('New stream: ' + stream.id);
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

  _addDataChannel(id, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      this.onDataChannelMessage?.call(channel, data);
    };
    _dataChannels[id] = channel;
    this.onDataChannel?.call(channel);
  }

  _createDataChannel(id, RTCPeerConnection pc, {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
    RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
    _addDataChannel(id, channel);
  }

  _createOffer(String id, RTCPeerConnection pc, String media, String? localMC) async {
    try {
      RTCSessionDescription s = await pc.createOffer(media == 'data' ? _dcConstraints : _constraints);
      pc.setLocalDescription(s);
      print('create offer mc=>$localMC');
      _send('offer', {
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
        'media': media,
        'mc': localMC
      });
    } catch (e) {
      print(e.toString());
    }
  }

  _createAnswer(String id, RTCPeerConnection pc, media) async {
    try {
      RTCSessionDescription s = await pc.createAnswer(media == 'data' ? _dcConstraints : _constraints);
      pc.setLocalDescription(s);
      _send('answer', {
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
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
}
