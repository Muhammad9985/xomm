import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef RemoteStreamCallback = void Function(String peerId, MediaStream stream);
typedef PeerDisconnectedCallback = void Function(String peerId);

/// Encapsulates WebRTC PeerConnection, state, and signaling subscriptions for a single peer.
class PeerConnectionContext {
  final String remotePeerId;
  final RTCPeerConnection peerConnection;
  final bool isCaller;
  StreamSubscription? signalingSub;
  StreamSubscription? candidateSub;
  final List<RTCIceCandidate> pendingCandidates = [];
  bool isRemoteDescriptionSet = false;
  bool isDisposed = false;
  MediaStream? remoteStream;

  PeerConnectionContext({
    required this.remotePeerId,
    required this.peerConnection,
    required this.isCaller,
  });

  Future<void> dispose() async {
    if (isDisposed) return;
    isDisposed = true;
    try {
      await signalingSub?.cancel();
      signalingSub = null;
      await candidateSub?.cancel();
      candidateSub = null;
      peerConnection.onIceCandidate = null;
      peerConnection.onTrack = null;
      peerConnection.onAddStream = null;
      peerConnection.onConnectionState = null;
      await remoteStream?.dispose();
      remoteStream = null;
      await peerConnection.close();
      await peerConnection.dispose();
    } catch (e) {
      debugPrint('[Signaling] Error disposing peer $remotePeerId: $e');
    }
  }
}

class SignalingManager {
  final String meetingId;
  final String userId;
  final bool isHost;

  MediaStream? _localStream;
  final Map<String, PeerConnectionContext> _peers = {};

  RemoteStreamCallback? onRemoteStream;
  PeerDisconnectedCallback? onPeerDisconnected;
  VoidCallback? onConnected;

  /// Injects voice-optimized parameters into the Opus SDP configuration:
  /// - stereo=0 & sprop-stereo=0: Forces mono audio so Acoustic Echo Cancellation (AEC) cancels 100% of echo
  /// - useinbandfec=1: Enables In-band Forward Error Correction to eliminate robotic crackles/distortion on packet loss
  /// - usedtx=1: Discontinuous Transmission stops sending noise when a participant is silent, eliminating ambient hiss/hum
  /// - maxaveragebitrate=32000: High-fidelity wideband voice bitrate
  /// - minptime=10 & ptime=20: Optimal packetization intervals for low latency and zero jitter buffer artifacts
  static String optimizeAudioSdp(String sdp) {
    final opusRtpMapRegex = RegExp(r'a=rtpmap:(\d+)\s+opus/48000/2', caseSensitive: false);
    final match = opusRtpMapRegex.firstMatch(sdp);
    if (match == null) return sdp;

    final pt = match.group(1);
    final fmtpPrefix = 'a=fmtp:$pt';
    final isCrLf = sdp.contains('\r\n');
    final delimiter = isCrLf ? '\r\n' : '\n';
    final lines = sdp.split(RegExp(r'\r?\n'));
    final newLines = <String>[];

    const opusVoiceParams =
        'minptime=10;ptime=20;useinbandfec=1;usedtx=1;stereo=0;sprop-stereo=0;maxaveragebitrate=32000;cbr=0';

    bool fmtpModified = false;

    for (var line in lines) {
      if (line.startsWith(fmtpPrefix)) {
        var content = line.substring(fmtpPrefix.length).trim();
        var params = <String, String>{};
        for (var part in content.split(';')) {
          final kv = part.split('=');
          if (kv.length == 2) {
            params[kv[0].trim()] = kv[1].trim();
          } else if (part.trim().isNotEmpty) {
            params[part.trim()] = '';
          }
        }
        params['minptime'] = '10';
        params['ptime'] = '20';
        params['useinbandfec'] = '1';
        params['usedtx'] = '1';
        params['stereo'] = '0';
        params['sprop-stereo'] = '0';
        params['maxaveragebitrate'] = '32000';
        params['cbr'] = '0';

        final updatedContent = params.entries
            .map((e) => e.value.isEmpty ? e.key : '${e.key}=${e.value}')
            .join(';');
        newLines.add('$fmtpPrefix $updatedContent');
        fmtpModified = true;
      } else {
        newLines.add(line);
      }
    }

    if (!fmtpModified) {
      final insertIndex = newLines.indexWhere((l) => l.startsWith('a=rtpmap:$pt'));
      if (insertIndex != -1) {
        newLines.insert(insertIndex + 1, '$fmtpPrefix $opusVoiceParams');
      }
    }

    return newLines.join(delimiter);
  }

  /// Ensures speakerphone/loudspeaker audio route is active on mobile without failing on PC
  static void ensureSpeakerphoneOn() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        Helper.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('[Signaling] setSpeakerphoneOn error: $e');
      }
    }
  }

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'url': 'stun:stun.l.google.com:19302',
        'urls': ['stun:stun.l.google.com:19302'],
      },
      {
        'url': 'stun:stun1.l.google.com:19302',
        'urls': ['stun:stun1.l.google.com:19302'],
      },
      {
        'url': 'stun:stun2.l.google.com:19302',
        'urls': ['stun:stun2.l.google.com:19302'],
      },
      {
        'url': 'stun:stun.services.mozilla.com',
        'urls': ['stun:stun.services.mozilla.com'],
      },
      {
        'url': 'stun:stun.relay.metered.ca:80',
        'urls': ['stun:stun.relay.metered.ca:80'],
      },
      {
        'url': 'turn:openrelay.metered.ca:80',
        'urls': ['turn:openrelay.metered.ca:80'],
        'username': 'openrelay',
        'credential': 'openrelay',
      },
      {
        'url': 'turn:openrelay.metered.ca:443',
        'urls': ['turn:openrelay.metered.ca:443'],
        'username': 'openrelay',
        'credential': 'openrelay',
      },
      {
        'url': 'turn:openrelay.metered.ca:443?transport=tcp',
        'urls': ['turn:openrelay.metered.ca:443?transport=tcp'],
        'username': 'openrelay',
        'credential': 'openrelay',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  SignalingManager({
    required this.meetingId,
    required this.userId,
    required this.isHost,
  });

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _db {
    if (_isFirebaseReady) {
      try {
        return FirebaseFirestore.instance;
      } catch (_) {}
    }
    return null;
  }

  String _getConnectionId(String peerId) {
    return userId.compareTo(peerId) < 0 ? '${userId}_$peerId' : '${peerId}_$userId';
  }

  /// Initialize local media stream (can be null for listen/view-only clients)
  Future<void> init(MediaStream? localStream) async {
    _localStream = localStream;
  }

  /// Replace outgoing video track on all active peer connections (e.g. screen share switch)
  Future<void> replaceVideoTrack(MediaStreamTrack newTrack, MediaStream newStream) async {
    _localStream = newStream;
    for (final ctx in _peers.values) {
      try {
        final senders = await ctx.peerConnection.getSenders();
        bool replaced = false;
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(newTrack);
            replaced = true;
          }
        }
        if (!replaced) {
          await ctx.peerConnection.addTrack(newTrack, newStream);
        }
      } catch (e) {
        debugPrint('[Signaling] Error replacing video track for ${ctx.remotePeerId}: $e');
      }
    }
  }

  /// Synchronize peer connections with current active remote participants
  Future<void> syncParticipants(List<String> remotePeerIds) async {
    final activeSet = remotePeerIds.where((id) => id != userId).toSet();

    // 1. Clean up peers that left
    final toRemove = _peers.keys.where((id) => !activeSet.contains(id)).toList();
    for (final peerId in toRemove) {
      debugPrint('[Signaling] Peer left, cleaning up: $peerId');
      final ctx = _peers.remove(peerId);
      await ctx?.dispose();
      onPeerDisconnected?.call(peerId);
    }

    // 2. Connect to new remote peers
    for (final remotePeerId in activeSet) {
      if (!_peers.containsKey(remotePeerId)) {
        await _connectToPeer(remotePeerId);
      }
    }
  }

  Future<void> _connectToPeer(String remotePeerId) async {
    final db = _db;
    if (db == null) {
      debugPrint('[Signaling] Firebase not ready for peer $remotePeerId');
      return;
    }

    // Deterministic caller/callee role assignment based on lexicographical order
    final isCaller = userId.compareTo(remotePeerId) < 0;
    final connId = _getConnectionId(remotePeerId);
    final connDocRef = db
        .collection('meetings')
        .doc(meetingId)
        .collection('signaling')
        .doc(connId);

    try {
      final pc = await createPeerConnection(_iceServers);

      // Add local audio and video tracks if available
      bool hasLocalAudio = false;
      bool hasLocalVideo = false;

      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          if (track.kind == 'audio') hasLocalAudio = true;
          if (track.kind == 'video') hasLocalVideo = true;
          await pc.addTrack(track, _localStream!);
        }
      }

      // If local audio is missing, add RecvOnly transceiver so remote audio can be negotiated and played
      if (!hasLocalAudio) {
        try {
          await pc.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        } catch (e) {
          debugPrint('[Signaling] Error adding audio transceiver: $e');
        }
      }

      // If local video is missing, add RecvOnly transceiver so remote video can be negotiated and displayed
      if (!hasLocalVideo) {
        try {
          await pc.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        } catch (e) {
          debugPrint('[Signaling] Error adding video transceiver: $e');
        }
      }

      final context = PeerConnectionContext(
        remotePeerId: remotePeerId,
        peerConnection: pc,
        isCaller: isCaller,
      );
      _peers[remotePeerId] = context;

      // Handle remote incoming tracks & streams from this peer
      pc.onTrack = (RTCTrackEvent event) async {
        debugPrint('[Signaling] Track received from $remotePeerId (${event.track.kind}), streams: ${event.streams.length}');
        event.track.enabled = true;
        if (event.track.kind == 'audio') {
          ensureSpeakerphoneOn();
        }
        MediaStream stream;
        if (event.streams.isNotEmpty) {
          stream = event.streams[0];
          context.remoteStream = stream;
        } else {
          // For video tracks, attach to remoteStream so RTCVideoRenderer can render frames.
          // For audio tracks, libwebrtc VoiceEngine already plays remote audio directly.
          // Never add audio tracks to createLocalMediaStream, as that creates a duplicate audio player pipeline (echo/repeated audio loop).
          context.remoteStream ??= await createLocalMediaStream('remote_$remotePeerId');
          if (event.track.kind == 'video') {
            context.remoteStream!.addTrack(event.track);
          }
          stream = context.remoteStream!;
        }
        onRemoteStream?.call(remotePeerId, stream);
      };

      // Crucial for Windows desktop WebRTC: native libwebrtc frequently fires onAddStream
      pc.onAddStream = (MediaStream stream) {
        debugPrint('[Signaling] onAddStream received from $remotePeerId: ${stream.id}, video tracks: ${stream.getVideoTracks().length}');
        if (context.remoteStream?.id != stream.id) {
          context.remoteStream = stream;
          ensureSpeakerphoneOn();
          onRemoteStream?.call(remotePeerId, stream);
        }
      };

      pc.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[Signaling] Peer $remotePeerId state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          ensureSpeakerphoneOn();
          onConnected?.call();
        }
      };

      if (isCaller) {
        // --- CALLER: Generates Offer, writes to callerCandidates, listens for answer ---
        pc.onIceCandidate = (RTCIceCandidate candidate) {
          if (candidate.candidate != null && !context.isDisposed) {
            connDocRef.collection('callerCandidates').add({
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            });
          }
        };

        final rawOffer = await pc.createOffer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 1,
        });
        final tunedOfferSdp = optimizeAudioSdp(rawOffer.sdp ?? '');
        final offer = RTCSessionDescription(tunedOfferSdp, rawOffer.type);
        await pc.setLocalDescription(offer);

        await connDocRef.set({
          'callerId': userId,
          'calleeId': remotePeerId,
          'offer': {'type': offer.type, 'sdp': offer.sdp},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Listen for Callee's Answer
        context.signalingSub = connDocRef.snapshots().listen((snapshot) async {
          if (context.isDisposed) return;
          final data = snapshot.data();
          if (data != null && data.containsKey('answer') && !context.isRemoteDescriptionSet) {
            context.isRemoteDescriptionSet = true;
            final answerMap = data['answer'] as Map<String, dynamic>;
            final answer = RTCSessionDescription(answerMap['sdp'], answerMap['type']);
            try {
              await pc.setRemoteDescription(answer);
              debugPrint('[Signaling] Remote description (answer) set successfully on caller');
            } catch (e) {
              debugPrint('[Signaling] Error setting remote answer on caller: $e');
              context.isRemoteDescriptionSet = false;
              return;
            }

            // Drain any queued candidates safely
            for (final c in context.pendingCandidates) {
              try {
                await pc.addCandidate(c);
              } catch (e) {
                debugPrint('[Signaling] Error adding queued candidate on caller: $e');
              }
            }
            context.pendingCandidates.clear();
          }
        }, onError: (e) {
          debugPrint('[Signaling] Caller signalingSub error: $e');
        });

        // Listen for Callee's ICE Candidates
        context.candidateSub = connDocRef
            .collection('calleeCandidates')
            .snapshots()
            .listen((snapshot) async {
          if (context.isDisposed) return;
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null && data['candidate'] != null) {
                final candidate = RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'] is num ? (data['sdpMLineIndex'] as num).toInt() : null,
                );
                if (context.isRemoteDescriptionSet) {
                  try {
                    await pc.addCandidate(candidate);
                  } catch (e) {
                    debugPrint('[Signaling] Error adding candidate on caller: $e');
                  }
                } else {
                  context.pendingCandidates.add(candidate);
                }
              }
            }
          }
        }, onError: (e) {
          debugPrint('[Signaling] Caller candidateSub error: $e');
        });
      } else {
        // --- CALLEE: Listens for Offer, writes to calleeCandidates, generates Answer ---
        pc.onIceCandidate = (RTCIceCandidate candidate) {
          if (candidate.candidate != null && !context.isDisposed) {
            connDocRef.collection('calleeCandidates').add({
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            });
          }
        };

        // Listen for Caller's Offer
        context.signalingSub = connDocRef.snapshots().listen((snapshot) async {
          if (context.isDisposed) return;
          final data = snapshot.data();
          if (data != null && data.containsKey('offer') && !context.isRemoteDescriptionSet) {
            context.isRemoteDescriptionSet = true;
            final offerMap = data['offer'] as Map<String, dynamic>;
            final offer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);
            
            try {
              await pc.setRemoteDescription(offer);
              debugPrint('[Signaling] Remote description (offer) set successfully on callee');
            } catch (e) {
              debugPrint('[Signaling] Error setting remote offer on callee: $e');
              context.isRemoteDescriptionSet = false;
              return;
            }

            // Create Answer and set local description FIRST before draining candidates!
            try {
              final rawAnswer = await pc.createAnswer({
                'offerToReceiveAudio': 1,
                'offerToReceiveVideo': 1,
              });
              final tunedAnswerSdp = optimizeAudioSdp(rawAnswer.sdp ?? '');
              final answer = RTCSessionDescription(tunedAnswerSdp, rawAnswer.type);
              await pc.setLocalDescription(answer);

              await connDocRef.set({
                'answer': {'type': answer.type, 'sdp': answer.sdp},
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              debugPrint('[Signaling] Callee answer written to Firestore with optimized Opus audio params');
            } catch (e) {
              debugPrint('[Signaling] Error creating/setting answer on callee: $e');
              return;
            }

            // Drain any queued candidates safely after local answer is active
            for (final c in context.pendingCandidates) {
              try {
                await pc.addCandidate(c);
              } catch (e) {
                debugPrint('[Signaling] Error adding queued candidate on callee: $e');
              }
            }
            context.pendingCandidates.clear();
          }
        }, onError: (e) {
          debugPrint('[Signaling] Callee signalingSub error: $e');
        });

        // Listen for Caller's ICE Candidates
        context.candidateSub = connDocRef
            .collection('callerCandidates')
            .snapshots()
            .listen((snapshot) async {
          if (context.isDisposed) return;
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null && data['candidate'] != null) {
                final candidate = RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'] is num ? (data['sdpMLineIndex'] as num).toInt() : null,
                );
                if (context.isRemoteDescriptionSet) {
                  try {
                    await pc.addCandidate(candidate);
                  } catch (e) {
                    debugPrint('[Signaling] Error adding candidate on callee: $e');
                  }
                } else {
                  context.pendingCandidates.add(candidate);
                }
              }
            }
          }
        }, onError: (e) {
          debugPrint('[Signaling] Callee candidateSub error: $e');
        });
      }
    } catch (e) {
      debugPrint('[Signaling] Error connecting to peer $remotePeerId: $e');
    }
  }

  /// Clean up all peer connections and subscriptions
  Future<void> dispose() async {
    for (final ctx in _peers.values) {
      await ctx.dispose();
    }
    _peers.clear();
  }
}
