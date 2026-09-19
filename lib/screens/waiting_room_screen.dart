import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/meeting_model.dart';
import '../services/meeting_service.dart';
import '../services/webrtc_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/meeting_code_pill.dart';
import '../widgets/xomm_button.dart';
import 'meeting_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final Meeting meeting;
  final String userId;
  final String userName;
  final bool initialAudioMuted;
  final bool initialVideoMuted;
  final WebRTCService? existingWebRTCService;

  const WaitingRoomScreen({
    super.key,
    required this.meeting,
    required this.userId,
    required this.userName,
    this.initialAudioMuted = false,
    this.initialVideoMuted = false,
    this.existingWebRTCService,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  StreamSubscription<JoinRequestStatus>? _subscription;
  StreamSubscription<Meeting?>? _meetingSubscription;
  bool _admitted = false;

  @override
  void initState() {
    super.initState();
    _listenToStatus();
  }

  void _listenToStatus() {
    // Watch join status
    _subscription = MeetingService.instance
        .watchJoinStatus(widget.meeting.id, widget.userId)
        .listen((status) {
      if (!mounted) return;

      if (status == JoinRequestStatus.accepted) {
        _admitted = true;
        // Host admitted the guest! Navigate to the call
        final isHost = widget.meeting.hostId.isNotEmpty && widget.meeting.hostId == widget.userId;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MeetingScreen(
              meeting: widget.meeting,
              userId: widget.userId,
              userName: widget.userName,
              isHost: isHost,
              initialAudioMuted: widget.initialAudioMuted,
              initialVideoMuted: widget.initialVideoMuted,
              existingWebRTCService: widget.existingWebRTCService,
            ),
          ),
        );
      } else if (status == JoinRequestStatus.rejected) {
        // Host rejected admission
        _showRejectedDialog();
      }
    });

    // Watch meeting status (if host ends meeting while guest is waiting)
    _meetingSubscription = MeetingService.instance
        .watchMeeting(widget.meeting.id)
        .listen((meeting) {
      if (!mounted || _admitted) return;
      if (meeting == null || meeting.isEnded) {
        widget.existingWebRTCService?.dispose();
        _subscription?.cancel();
        _meetingSubscription?.cancel();
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'This meeting has ended.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentDanger,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppTheme.accentDanger),
            SizedBox(width: 10),
            Text('Request Declined'),
          ],
        ),
        content: Text(
          'The host declined your request to join ${widget.meeting.title}.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          XommButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // back to home
            },
            variant: XommButtonVariant.secondary,
            text: 'Back to Home',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _meetingSubscription?.cancel();
    if (!_admitted) {
      widget.existingWebRTCService?.dispose();
    }
    super.dispose();
  }

  void _handleLeave() {
    MeetingService.instance.leaveMeeting(widget.meeting.id, widget.userId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background subtle ambient light
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            left: MediaQuery.of(context).size.width * 0.3,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryCyan.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withOpacity(0.12),
                    blurRadius: 180,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(36),
                    borderRadius: 28,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated pulsing radar / waiting ring
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryCyan.withOpacity(0.06),
                                  border: Border.all(
                                    color: AppTheme.primaryCyan.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat())
                                  .scale(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1.25, 1.25),
                                    duration: 2000.ms,
                                    curve: Curves.easeOutQuad,
                                  )
                                  .fadeOut(begin: 1.0, duration: 2000.ms),
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.brandGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryCyan.withOpacity(0.4),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.hourglass_empty_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        const Text(
                          'Waiting for Host',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Please wait, ${widget.meeting.hostName} will let you into the meeting shortly.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Meeting Details Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLighter.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Meeting Title:',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                  Text(
                                    widget.meeting.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white10, height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Meeting Code:',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                  MeetingCodePill(code: widget.meeting.code, fontSize: 12),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        XommButton(
                          onPressed: _handleLeave,
                          variant: XommButtonVariant.glass,
                          text: 'Leave Waiting Room',
                          icon: Icons.logout_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
