import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

class VideoTile extends StatelessWidget {
  final String participantName;
  final bool isHost;
  final bool isLocal;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isSpeaking;
  final bool isScreenSharing;
  final RTCVideoRenderer? renderer;
  final VoidCallback? onTogglePin;
  final bool isPinned;

  const VideoTile({
    super.key,
    required this.participantName,
    this.isHost = false,
    this.isLocal = false,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.isSpeaking = false,
    this.isScreenSharing = false,
    this.renderer,
    this.onTogglePin,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveVideo = renderer != null &&
        renderer!.srcObject != null &&
        renderer!.srcObject!.getVideoTracks().isNotEmpty &&
        !isVideoMuted;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking
              ? AppTheme.accentGreen
              : (isPinned
                  ? AppTheme.primaryCyan
                  : Colors.white.withOpacity(0.1)),
          width: isSpeaking || isPinned ? 2 : 1,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: AppTheme.accentGreen.withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Video Stream or Fallback Avatar
            Positioned.fill(
              child: hasActiveVideo
                  ? RTCVideoView(
                      renderer!,
                      objectFit: isScreenSharing
                          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                          : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: isScreenSharing ? false : isLocal,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.surfaceGradient,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.brandGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSpeaking
                                            ? AppTheme.accentGreen
                                            : AppTheme.primaryCyan)
                                        .withOpacity(0.4),
                                    blurRadius: isSpeaking ? 24 : 12,
                                    spreadRadius: isSpeaking ? 4 : 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  participantName.isNotEmpty
                                      ? participantName[0].toUpperCase()
                                      : 'X',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              participantName + (isLocal ? ' (You)' : ''),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Top-right status indicators
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onTogglePin != null)
                    GestureDetector(
                      onTap: onTogglePin,
                      child: GlassContainer(
                        padding: const EdgeInsets.all(6),
                        borderRadius: 8,
                        child: Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 14,
                          color: isPinned ? AppTheme.primaryCyan : Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom-left info pill (Name + Mic state + Host tag)
            Positioned(
              bottom: 10,
              left: 10,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                borderRadius: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: 14,
                      color: isAudioMuted
                          ? AppTheme.accentDanger
                          : AppTheme.accentGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      participantName + (isLocal ? ' (You)' : ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryViolet.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.secondaryViolet.withOpacity(0.5),
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: AppTheme.secondaryVioletGlow,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (isScreenSharing) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.primaryCyan.withOpacity(0.6),
                            width: 0.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.screen_share_rounded,
                                color: AppTheme.primaryCyan, size: 10),
                            SizedBox(width: 3),
                            Text(
                              'SCREEN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
