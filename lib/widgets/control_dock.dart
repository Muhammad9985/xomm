import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

class ControlDock extends StatelessWidget {
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isScreenSharing;
  final int pendingWaitingRoomCount;
  final int participantCount;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onOpenParticipants;
  final VoidCallback onOpenChat;
  final VoidCallback onLeaveMeeting;

  const ControlDock({
    super.key,
    required this.isAudioMuted,
    required this.isVideoMuted,
    required this.isScreenSharing,
    required this.pendingWaitingRoomCount,
    required this.participantCount,
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onSwitchCamera,
    required this.onToggleScreenShare,
    required this.onOpenParticipants,
    required this.onOpenChat,
    required this.onLeaveMeeting,
  });

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    required double size,
    required double iconSize,
    Color? activeColor,
    Color? inactiveColor,
    String? tooltip,
    int? badgeCount,
  }) {
    final bgColor = isActive
        ? (activeColor ?? AppTheme.primaryCyan)
        : (inactiveColor ?? AppTheme.surfaceLighter);

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(isActive ? 0.3 : 0.1),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: bgColor.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white,
            ),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentAmber.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final btnSize = isMobile ? 42.0 : 50.0;
    final iconSize = isMobile ? 19.0 : 22.0;
    final spacing = isMobile ? 8.0 : 12.0;

    return GlassContainer(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: isMobile ? 8 : 12,
      ),
      borderRadius: 32,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Audio Mute/Unmute
            _buildCircleButton(
              size: btnSize,
              iconSize: iconSize,
              icon: isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              onPressed: onToggleAudio,
              isActive: !isAudioMuted,
              activeColor: AppTheme.surfaceLighter,
              inactiveColor: AppTheme.accentDanger,
              tooltip: isAudioMuted ? 'Unmute Audio' : 'Mute Audio',
            ),
            SizedBox(width: spacing),

            // Video On/Off
            _buildCircleButton(
              size: btnSize,
              iconSize: iconSize,
              icon: isVideoMuted
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              onPressed: onToggleVideo,
              isActive: !isVideoMuted,
              activeColor: AppTheme.surfaceLighter,
              inactiveColor: AppTheme.accentDanger,
              tooltip: isVideoMuted ? 'Start Video' : 'Stop Video',
            ),
            SizedBox(width: spacing),

            // Flip Camera
            _buildCircleButton(
              size: btnSize,
              iconSize: iconSize,
              icon: Icons.flip_camera_ios_rounded,
              onPressed: onSwitchCamera,
              isActive: false,
              tooltip: 'Flip Camera',
            ),
            SizedBox(width: spacing),

            // Share Screen (Desktop/Tablet)
            if (!isMobile) ...[
              _buildCircleButton(
                size: btnSize,
                iconSize: iconSize,
                icon: isScreenSharing
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                onPressed: onToggleScreenShare,
                isActive: isScreenSharing,
                activeColor: AppTheme.primaryCyan,
                tooltip: isScreenSharing ? 'Stop Screen Share' : 'Share Screen',
              ),
              SizedBox(width: spacing),
            ],

            // Participants & Waiting Room
            _buildCircleButton(
              size: btnSize,
              iconSize: iconSize,
              icon: Icons.people_alt_rounded,
              onPressed: onOpenParticipants,
              isActive: pendingWaitingRoomCount > 0,
              activeColor: AppTheme.accentAmber,
              badgeCount: pendingWaitingRoomCount,
              tooltip: 'Participants ($participantCount)',
            ),
            SizedBox(width: spacing),

            // Chat
            _buildCircleButton(
              size: btnSize,
              iconSize: iconSize,
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: onOpenChat,
              isActive: false,
              tooltip: 'Meeting Chat',
            ),
            SizedBox(width: spacing + (isMobile ? 0 : 4)),

            // End / Leave Meeting
            if (isMobile)
              _buildCircleButton(
                size: btnSize,
                iconSize: iconSize,
                icon: Icons.call_end_rounded,
                onPressed: onLeaveMeeting,
                isActive: true,
                activeColor: AppTheme.accentDanger,
                tooltip: 'Leave Meeting',
              )
            else
              Tooltip(
                message: 'Leave Meeting',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onLeaveMeeting,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      height: btnSize,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        gradient: AppTheme.dangerGradient,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentDanger.withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call_end_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'End',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
