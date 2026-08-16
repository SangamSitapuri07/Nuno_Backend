import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'socket_events.dart';
import 'socket_service.dart';

/// Mesh WebRTC voice chat for a room.
///
/// The backend (src/voice/voice.handler.ts) is purely a signalling relay: it
/// forwards `voice.offer`, `voice.answer` and `voice.iceCandidate` between
/// participants and announces joins and leaves. Media itself is peer to peer,
/// so this class owns the microphone track and one [RTCPeerConnection] per
/// remote participant.
///
/// A mesh is the right shape here: rooms cap at ten players and are usually
/// far smaller, so no SFU is warranted.
class VoiceService {
  final SocketService _socket;

  VoiceService(this._socket);

  MediaStream? _localStream;

  /// remote userId -> connection
  final Map<String, RTCPeerConnection> _peers = {};

  /// remote userId -> their inbound audio
  final Map<String, MediaStream> _remoteStreams = {};

  /// Candidates that arrived before the remote description was applied.
  /// Adding one early throws, so they are held until the description lands.
  final Map<String, List<RTCIceCandidate>> _earlyCandidates = {};

  final List<StreamSubscription> _subs = [];

  bool _active = false;
  bool _muted = false;
  String? _roomId;

  final _stateController = StreamController<VoiceState>.broadcast();
  Stream<VoiceState> get onStateChanged => _stateController.stream;

  bool get isActive => _active;
  bool get isMuted => _muted;
  int get peerCount => _peers.length;

  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    // Bundling keeps a single transport for the audio track.
    'sdpSemantics': 'unified-plan',
  };

  static const Map<String, dynamic> _audioOnly = {
    'audio': true,
    'video': false,
  };

  // ── Lifecycle ───────────────────────────────────────────────

  /// Requests the microphone and joins the room's voice channel.
  ///
  /// Returns false when permission is refused, so the caller can leave the
  /// mic button visibly off rather than pretending it worked.
  Future<bool> join(String roomId) async {
    if (_active) return true;

    final granted = await Permission.microphone.request();
    if (!granted.isGranted) {
      debugPrint('[voice] microphone permission denied');
      _emit();
      return false;
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(_audioOnly);
    } catch (e) {
      debugPrint('[voice] getUserMedia failed: $e');
      _emit();
      return false;
    }

    _roomId = roomId;
    _active = true;
    _listen();
    _socket.emit(SocketEvents.voiceJoin, {'roomId': roomId});
    _emit();
    return true;
  }

  Future<void> leave() async {
    if (!_active) return;

    _socket.emit(SocketEvents.voiceLeave);

    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    for (final peer in _peers.values) {
      await peer.close();
    }
    _peers.clear();

    for (final stream in _remoteStreams.values) {
      await stream.dispose();
    }
    _remoteStreams.clear();
    _earlyCandidates.clear();

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;

    _active = false;
    _muted = false;
    _roomId = null;
    _emit();
  }

  /// Mutes locally and tells the room, so other clients can show it.
  void setMuted(bool muted) {
    _muted = muted;
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    if (_active) _socket.emit(SocketEvents.voiceMute, {'isMuted': muted});
    _emit();
  }

  /// Silences everyone else without touching the microphone.
  void setSpeakerEnabled(bool enabled) {
    for (final stream in _remoteStreams.values) {
      for (final track in stream.getAudioTracks()) {
        track.enabled = enabled;
      }
    }
  }

  Future<void> dispose() async {
    await leave();
    await _stateController.close();
  }

  // ── Signalling ──────────────────────────────────────────────

  void _listen() {
    void sub(String event, Future<void> Function(Map<String, dynamic>) fn) {
      _subs.add(_socket.on(event).listen((p) => fn(p)));
    }

    // Our own join was accepted, and we are told who is already here. The
    // joiner initiates towards each of them; they answer. Doing it in this
    // direction avoids two peers offering each other at once (glare).
    sub(SocketEvents.voiceJoined, (p) async {
      final existing = p['existingParticipants'];
      if (existing is! List) return;
      for (final entry in existing) {
        if (entry is! Map) continue;
        final userId = entry['userId']?.toString();
        if (userId != null) await _offerTo(userId);
      }
    });

    // Someone arrived after us: they will offer, so just wait.
    sub(SocketEvents.voiceUserJoined, (p) async {
      debugPrint('[voice] ${p['username']} joined the channel');
    });

    sub(SocketEvents.voiceOffer, (p) async {
      final from = p['fromUserId']?.toString();
      final sdp = p['offer'];
      if (from == null || sdp is! Map) return;

      final peer = await _peerFor(from);
      await peer.setRemoteDescription(
        RTCSessionDescription(sdp['sdp']?.toString(), sdp['type']?.toString()),
      );
      await _drainCandidates(from, peer);

      final answer = await peer.createAnswer();
      await peer.setLocalDescription(answer);

      _socket.emit(SocketEvents.voiceAnswer, {
        'targetUserId': from,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    sub(SocketEvents.voiceAnswer, (p) async {
      final from = p['fromUserId']?.toString();
      final sdp = p['answer'];
      if (from == null || sdp is! Map) return;

      final peer = _peers[from];
      if (peer == null) return;
      await peer.setRemoteDescription(
        RTCSessionDescription(sdp['sdp']?.toString(), sdp['type']?.toString()),
      );
      await _drainCandidates(from, peer);
    });

    sub(SocketEvents.voiceIceCandidate, (p) async {
      final from = p['fromUserId']?.toString();
      final raw = p['candidate'];
      if (from == null || raw is! Map) return;

      final candidate = RTCIceCandidate(
        raw['candidate']?.toString(),
        raw['sdpMid']?.toString(),
        raw['sdpMLineIndex'] is int ? raw['sdpMLineIndex'] as int : null,
      );

      final peer = _peers[from];
      final remoteSet =
          peer != null && (await peer.getRemoteDescription()) != null;

      if (remoteSet) {
        await peer.addCandidate(candidate);
      } else {
        (_earlyCandidates[from] ??= []).add(candidate);
      }
    });

    sub(SocketEvents.voiceLeft, (p) async {
      final userId = p['userId']?.toString();
      if (userId != null) await _removePeer(userId);
    });
  }

  Future<void> _offerTo(String userId) async {
    final peer = await _peerFor(userId);
    final offer = await peer.createOffer({'offerToReceiveAudio': true});
    await peer.setLocalDescription(offer);

    _socket.emit(SocketEvents.voiceOffer, {
      'targetUserId': userId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<RTCPeerConnection> _peerFor(String userId) async {
    final existing = _peers[userId];
    if (existing != null) return existing;

    final peer = await createPeerConnection(_rtcConfig);

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await peer.addTrack(track, _localStream!);
    }

    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _socket.emit(SocketEvents.voiceIceCandidate, {
        'targetUserId': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    peer.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remoteStreams[userId] = event.streams.first;
      _emit();
    };

    peer.onConnectionState = (state) {
      debugPrint('[voice] peer $userId -> $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _removePeer(userId);
      }
    };

    _peers[userId] = peer;
    _emit();
    return peer;
  }

  Future<void> _drainCandidates(String userId, RTCPeerConnection peer) async {
    final queued = _earlyCandidates.remove(userId);
    if (queued == null) return;
    for (final candidate in queued) {
      await peer.addCandidate(candidate);
    }
  }

  Future<void> _removePeer(String userId) async {
    final peer = _peers.remove(userId);
    await peer?.close();
    final stream = _remoteStreams.remove(userId);
    await stream?.dispose();
    _earlyCandidates.remove(userId);
    _emit();
  }

  void _emit() {
    if (_stateController.isClosed) return;
    _stateController.add(
      VoiceState(
        active: _active,
        muted: _muted,
        peers: _peers.length,
        roomId: _roomId,
      ),
    );
  }
}

@immutable
class VoiceState {
  final bool active;
  final bool muted;
  final int peers;
  final String? roomId;

  const VoiceState({
    this.active = false,
    this.muted = false,
    this.peers = 0,
    this.roomId,
  });
}
