import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_manager.dart';

class WebRTCService {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  MediaStream? _localStream;
  MediaStream? _cameraStream;
  MediaStream? _screenStream;
  SignalingManager? _signalingManager;

  bool isAudioMuted = false;
  bool isVideoMuted = false;
  bool isScreenSharing = false;
  bool _isInitialized = false;
  bool _isRemoteConnected = false;

  bool get isInitialized => _isInitialized;
  bool get isRemoteConnected => _isRemoteConnected || remoteRenderers.isNotEmpty;
  MediaStream? get localStream => _localStream;

  /// Compatibility fallback for 1-on-1 screens
  RTCVideoRenderer get remoteRenderer {
    if (remoteRenderers.isNotEmpty) {
      return remoteRenderers.values.first;
    }
    return localRenderer;
  }

  /// Get the dedicated renderer for a specific participant
  RTCVideoRenderer? getRendererForPeer(String peerId) {
    return remoteRenderers[peerId];
  }

  /// Initialize local video renderer and request camera/mic
  Future<bool> initLocalStream({
    bool startWithVideo = true,
    bool startWithAudio = true,
  }) async {
    try {
      await localRenderer.initialize();

      final isDesktop = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux);

      final audioConstraints = <String, dynamic>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      };

      final mediaConstraints = <String, dynamic>{
        'audio': audioConstraints,
        'video': isDesktop
            ? {
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
              }
            : {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'idealWidth': '1280',
                  'idealHeight': '720',
                  'minFrameRate': '20',
                  'idealFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        debugPrint('[WebRTC] Successfully acquired preferred Audio+Video stream');
      } catch (e) {
        debugPrint('[WebRTC] Preferred constraints failed ($e), retrying with standard constraints...');
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': true,
          });
          debugPrint('[WebRTC] Successfully acquired standard Audio+Video stream');
        } catch (e2) {
          debugPrint('[WebRTC] Standard Audio+Video capture failed ($e2), trying Video-only...');
          try {
            _localStream = await navigator.mediaDevices.getUserMedia({
              'audio': false,
              'video': true,
            });
            debugPrint('[WebRTC] Successfully acquired Video-Only stream');
          } catch (e3) {
            debugPrint('[WebRTC] Video-only capture failed ($e3), trying Audio-only...');
            try {
              _localStream = await navigator.mediaDevices.getUserMedia({
                'audio': true,
                'video': false,
              });
              debugPrint('[WebRTC] Successfully acquired Audio-Only stream');
            } catch (e4) {
              debugPrint('[WebRTC] Neither camera nor microphone available ($e4). Operating in Receive-Only mode.');
              _localStream = null;
            }
          }
        }
      }

      // If we have video but no audio tracks (common on some PC/laptop drivers), explicitly detect and capture microphone!
      if (_localStream != null && _localStream!.getAudioTracks().isEmpty) {
        debugPrint('[WebRTC] Video acquired but audio missing. Probing microphone devices on PC/Laptop...');
        try {
          final devices = await navigator.mediaDevices.enumerateDevices();
          final audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
          debugPrint('[WebRTC] Enumerated ${audioInputs.length} audio input devices');

          MediaStream? micStream;
          if (audioInputs.isNotEmpty) {
            final firstMicId = audioInputs.first.deviceId;
            try {
              micStream = await navigator.mediaDevices.getUserMedia({
                'audio': {
                  'echoCancellation': true,
                  'noiseSuppression': true,
                  'autoGainControl': true,
                  if (firstMicId.isNotEmpty) 'deviceId': {'exact': firstMicId},
                },
                'video': false,
              });
            } catch (micErr) {
              debugPrint('[WebRTC] Specific mic deviceId failed ($micErr), trying generic audio...');
              micStream = await navigator.mediaDevices.getUserMedia({
                'audio': true,
                'video': false,
              });
            }
          } else {
            micStream = await navigator.mediaDevices.getUserMedia({
              'audio': true,
              'video': false,
            });
          }

          if (micStream.getAudioTracks().isNotEmpty) {
            for (var track in micStream.getAudioTracks()) {
              _localStream!.addTrack(track);
              debugPrint('[WebRTC] Successfully added dedicated microphone track to localStream: ${track.id}');
            }
          }
        } catch (audioFallbackErr) {
          debugPrint('[WebRTC] Microphone probe/acquisition failed: $audioFallbackErr');
        }
      }

      if (_localStream != null) {
        localRenderer.srcObject = _localStream;
        final audioTracks = _localStream!.getAudioTracks();
        final hasAudio = audioTracks.isNotEmpty;

        if (!startWithVideo) {
          setVideoMute(true);
        } else {
          isVideoMuted = false;
        }

        if (!startWithAudio || !hasAudio) {
          setAudioMute(true);
        } else {
          isAudioMuted = false;
          for (var t in audioTracks) {
            t.enabled = true;
          }
        }
      } else {
        isAudioMuted = true;
        isVideoMuted = true;
      }

      _isInitialized = true;
      _cameraStream = _localStream;
      SignalingManager.ensureSpeakerphoneOn();

      return _localStream != null;
    } catch (e) {
      debugPrint('[WebRTC] Error accessing camera/mic: $e');
      _isInitialized = true;
      isAudioMuted = true;
      isVideoMuted = true;
      return false;
    }
  }

  /// Start P2P WebRTC Multi-Mesh Signaling
  Future<void> startSignaling({
    required String meetingId,
    required String userId,
    required bool isHost,
    VoidCallback? onStreamChanged,
  }) async {
    if (!_isInitialized) {
      await initLocalStream();
    }

    _signalingManager = SignalingManager(
      meetingId: meetingId,
      userId: userId,
      isHost: isHost,
    );

    _signalingManager!.onRemoteStream = (peerId, stream) async {
      debugPrint('[WebRTC] Got remote stream for peer $peerId with ${stream.getVideoTracks().length} video tracks');
      
      RTCVideoRenderer renderer;
      if (!remoteRenderers.containsKey(peerId)) {
        renderer = RTCVideoRenderer();
        remoteRenderers[peerId] = renderer; // Register immediately to prevent race conditions
        await renderer.initialize();
      } else {
        renderer = remoteRenderers[peerId]!;
      }

      // Avoid redundant re-binding if already attached to this stream with active video
      if (renderer.srcObject?.id != stream.id || renderer.srcObject!.getVideoTracks().isEmpty) {
        renderer.srcObject = stream;
      }

      // Listen for video tracks added dynamically after initial stream connection
      stream.onAddTrack = (track) {
        debugPrint('[WebRTC] onAddTrack for peer $peerId: ${track.kind}');
        if (remoteRenderers.containsKey(peerId)) {
          remoteRenderers[peerId]!.srcObject = null;
          remoteRenderers[peerId]!.srcObject = stream;
          onStreamChanged?.call();
        }
      };

      stream.onRemoveTrack = (track) {
        debugPrint('[WebRTC] onRemoveTrack for peer $peerId: ${track.kind}');
        onStreamChanged?.call();
      };

      _isRemoteConnected = remoteRenderers.isNotEmpty;
      SignalingManager.ensureSpeakerphoneOn();
      onStreamChanged?.call();
    };

    _signalingManager!.onPeerDisconnected = (peerId) async {
      debugPrint('[WebRTC] Disconnecting renderer for peer $peerId');
      if (remoteRenderers.containsKey(peerId)) {
        final renderer = remoteRenderers.remove(peerId);
        renderer?.srcObject = null;
        await renderer?.dispose();
        _isRemoteConnected = remoteRenderers.isNotEmpty;
        onStreamChanged?.call();
      }
    };

    _signalingManager!.onConnected = () {
      debugPrint('[WebRTC] P2P Peer Connection Established!');
      _isRemoteConnected = remoteRenderers.isNotEmpty;
      onStreamChanged?.call();
    };

    await _signalingManager!.init(_localStream);
  }

  /// Synchronize peer connections with current remote participant list
  void syncParticipants(List<String> remotePeerIds) {
    _signalingManager?.syncParticipants(remotePeerIds);
  }

  /// Toggle Audio (Mute / Unmute)
  bool toggleAudio() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        isAudioMuted = !isAudioMuted;
        for (var track in audioTracks) {
          track.enabled = !isAudioMuted;
        }
        return isAudioMuted;
      }
    }
    isAudioMuted = !isAudioMuted;
    return isAudioMuted;
  }

  /// Explicitly set Audio mute
  void setAudioMute(bool mute) {
    isAudioMuted = mute;
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !mute;
      }
    }
  }

  /// Toggle Video (Camera on / off)
  bool toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        isVideoMuted = !isVideoMuted;
        for (var track in videoTracks) {
          track.enabled = !isVideoMuted;
        }
        return isVideoMuted;
      }
    }
    isVideoMuted = !isVideoMuted;
    return isVideoMuted;
  }

  /// Explicitly set Video mute
  void setVideoMute(bool mute) {
    isVideoMuted = mute;
    if (_localStream != null) {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = !mute;
      }
    }
  }

  /// Switch Camera (Front <-> Back)
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final track = videoTracks.first;
        await Helper.switchCamera(track);
      }
    }
  }

  /// Screen Sharing Toggle
  Future<bool> toggleScreenShare({VoidCallback? onScreenShareEnded}) async {
    try {
      if (isScreenSharing) {
        await stopScreenShare();
        onScreenShareEnded?.call();
        return false;
      } else {
        return await startScreenShare(onScreenShareEnded: onScreenShareEnded);
      }
    } catch (e) {
      debugPrint('[WebRTC] toggleScreenShare error: $e');
      return isScreenSharing;
    }
  }

  /// Start Screen Sharing
  Future<bool> startScreenShare({VoidCallback? onScreenShareEnded}) async {
    try {
      MediaStream? screenStream;
      final isDesktop = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux);

      if (isDesktop) {
        try {
          final sources = await desktopCapturer.getSources(types: [SourceType.Screen]);
          final source = sources.isNotEmpty ? sources.first : null;
          screenStream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
            'video': source == null
                ? true
                : {
                    'deviceId': {'exact': source.id},
                    'mandatory': {'frameRate': 30.0},
                  },
            'audio': false,
          });
        } catch (desktopErr) {
          debugPrint('[WebRTC] Desktop screen capturer fallback: $desktopErr');
          screenStream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
            'video': true,
            'audio': false,
          });
        }
      } else {
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            await Helper.requestCapturePermission();
          } catch (permErr) {
            debugPrint('[WebRTC] Android requestCapturePermission: $permErr');
          }
        }
        screenStream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
          'video': true,
          'audio': false,
        });
      }

      if (screenStream.getVideoTracks().isEmpty) {
        debugPrint('[WebRTC] Screen stream has no video tracks');
        return false;
      }

      _screenStream = screenStream;
      final screenVideoTrack = screenStream.getVideoTracks().first;

      // Handle user stopping screen share via OS control or notification
      screenVideoTrack.onEnded = () {
        debugPrint('[WebRTC] Screen sharing track ended by system/OS');
        stopScreenShare();
        onScreenShareEnded?.call();
      };

      // Keep original camera stream reference
      _cameraStream ??= _localStream;

      // Create composite stream containing the screen video track + original mic track
      final compositeStream = await createLocalMediaStream('screen_with_mic');
      compositeStream.addTrack(screenVideoTrack);
      if (_cameraStream != null) {
        for (final audioTrack in _cameraStream!.getAudioTracks()) {
          compositeStream.addTrack(audioTrack);
        }
      }

      _localStream = compositeStream;
      localRenderer.srcObject = compositeStream;
      isScreenSharing = true;

      // Swap outgoing video track on all active peer connections so remote participants see the screen
      await _signalingManager?.replaceVideoTrack(screenVideoTrack, compositeStream);

      return true;
    } catch (e) {
      debugPrint('[WebRTC] Failed to start screen share: $e');
      return false;
    }
  }

  /// Stop Screen Sharing and restore camera
  Future<void> stopScreenShare() async {
    if (!isScreenSharing) return;
    try {
      isScreenSharing = false;

      // Stop and dispose screen track
      _screenStream?.getTracks().forEach((track) => track.stop());
      await _screenStream?.dispose();
      _screenStream = null;

      // Restore camera stream
      if (_cameraStream != null) {
        _localStream = _cameraStream;
        localRenderer.srcObject = _cameraStream;

        final cameraVideoTrack = _cameraStream!.getVideoTracks().firstOrNull;
        if (cameraVideoTrack != null) {
          cameraVideoTrack.enabled = !isVideoMuted;
          await _signalingManager?.replaceVideoTrack(cameraVideoTrack, _cameraStream!);
        }
      } else {
        await initLocalStream(
          startWithVideo: !isVideoMuted,
          startWithAudio: !isAudioMuted,
        );
      }
    } catch (e) {
      debugPrint('[WebRTC] Error stopping screen share: $e');
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    try {
      await _signalingManager?.dispose();
      _signalingManager = null;

      _screenStream?.getTracks().forEach((track) => track.stop());
      await _screenStream?.dispose();
      _screenStream = null;

      _cameraStream?.getTracks().forEach((track) => track.stop());
      await _cameraStream?.dispose();
      _cameraStream = null;

      _localStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
      _localStream = null;

      localRenderer.srcObject = null;
      await localRenderer.dispose();

      for (var r in remoteRenderers.values) {
        r.srcObject = null;
        await r.dispose();
      }
      remoteRenderers.clear();

      _isInitialized = false;
      _isRemoteConnected = false;
    } catch (e) {
      debugPrint('WebRTC dispose error: $e');
    }
  }
}
