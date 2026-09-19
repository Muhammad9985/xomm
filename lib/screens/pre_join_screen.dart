import 'package:flutter/material.dart';
import '../models/meeting_model.dart';
import '../services/meeting_service.dart';
import '../services/webrtc_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/meeting_code_pill.dart';
import '../widgets/video_tile.dart';
import '../widgets/xomm_button.dart';
import 'meeting_screen.dart';
import 'waiting_room_screen.dart';

class PreJoinScreen extends StatefulWidget {
  final Meeting meeting;

  const PreJoinScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends State<PreJoinScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Guest');
  final WebRTCService _webrtcService = WebRTCService();
  bool _isRequesting = false;
  bool _isMediaReady = false;
  bool _joinedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  Future<void> _initMedia() async {
    await _webrtcService.initLocalStream();
    if (mounted) setState(() => _isMediaReady = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (!_joinedSuccessfully) {
      _webrtcService.dispose();
    }
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final userName = _nameController.text.trim().isEmpty
        ? 'Guest'
        : _nameController.text.trim();

    setState(() => _isRequesting = true);
    final userId = DeviceIdManager.id;

    try {
      final status = await MeetingService.instance.requestToJoin(
        meetingId: widget.meeting.id,
        userId: userId,
        userName: userName,
      );

      if (!mounted) return;

      if (status == JoinRequestStatus.accepted) {
        _joinedSuccessfully = true;
        // Auto-accepted by host! Enter meeting immediately
        final isHost = widget.meeting.hostId.isNotEmpty && widget.meeting.hostId == userId;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MeetingScreen(
              meeting: widget.meeting,
              userId: userId,
              userName: userName,
              isHost: isHost,
              initialAudioMuted: _webrtcService.isAudioMuted,
              initialVideoMuted: _webrtcService.isVideoMuted,
              existingWebRTCService: _webrtcService,
            ),
          ),
        );
      } else {
        _joinedSuccessfully = true;
        // Host has auto-accept OFF -> Transition to Waiting Room Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingRoomScreen(
              meeting: widget.meeting,
              userId: userId,
              userName: userName,
              initialAudioMuted: _webrtcService.isAudioMuted,
              initialVideoMuted: _webrtcService.isVideoMuted,
              existingWebRTCService: _webrtcService,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join: $e'),
          backgroundColor: AppTheme.accentDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Meeting Preview'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: MeetingCodePill(code: widget.meeting.code, fontSize: 13),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: _buildVideoPreview()),
                      const SizedBox(width: 36),
                      Expanded(flex: 4, child: _buildControlsCard()),
                    ],
                  )
                : Column(
                    children: [
                      _buildVideoPreview(),
                      const SizedBox(height: 24),
                      _buildControlsCard(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        children: [
          Positioned.fill(
            child: VideoTile(
              participantName: _nameController.text.isEmpty ? 'You' : _nameController.text,
              isLocal: true,
              isAudioMuted: _webrtcService.isAudioMuted,
              isVideoMuted: _webrtcService.isVideoMuted,
              renderer: _isMediaReady ? _webrtcService.localRenderer : null,
            ),
          ),

          // Bottom floating quick camera/mic toggles
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                borderRadius: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _webrtcService.isAudioMuted ? 'Unmute' : 'Mute',
                      icon: Icon(
                        _webrtcService.isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: _webrtcService.isAudioMuted ? AppTheme.accentDanger : AppTheme.accentGreen,
                      ),
                      onPressed: () {
                        setState(() {
                          _webrtcService.toggleAudio();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: _webrtcService.isVideoMuted ? 'Start Video' : 'Stop Video',
                      icon: Icon(
                        _webrtcService.isVideoMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        color: _webrtcService.isVideoMuted ? AppTheme.accentDanger : AppTheme.primaryCyan,
                      ),
                      onPressed: () {
                        setState(() {
                          _webrtcService.toggleVideo();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Flip Camera',
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      onPressed: () async {
                        await _webrtcService.switchCamera();
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.meeting.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hosted by ${widget.meeting.hostName}',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Display Name
          const Text(
            'What should we call you?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onChanged: (val) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceLighter.withOpacity(0.5),
              prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.textSecondary, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primaryCyan),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Room mode notification
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (widget.meeting.autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (widget.meeting.autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber)
                    .withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.meeting.autoAccept ? Icons.door_front_door_outlined : Icons.hourglass_top_rounded,
                  size: 18,
                  color: widget.meeting.autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.meeting.autoAccept
                        ? 'Instant access: Auto-accept is enabled for this room.'
                        : 'Waiting room is enabled. Host must admit you.',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.meeting.autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          XommButton(
            onPressed: _handleJoin,
            isLoading: _isRequesting,
            width: double.infinity,
            variant: XommButtonVariant.primary,
            text: widget.meeting.autoAccept ? 'Join Meeting' : 'Ask to Join',
            icon: widget.meeting.autoAccept ? Icons.login_rounded : Icons.lock_open_rounded,
          ),
        ],
      ),
    );
  }
}
