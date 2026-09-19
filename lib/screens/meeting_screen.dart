import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meeting_model.dart';
import '../services/meeting_service.dart';
import '../services/webrtc_service.dart';
import '../theme/app_theme.dart';
import '../widgets/control_dock.dart';
import '../widgets/glass_container.dart';
import '../widgets/meeting_code_pill.dart';
import '../widgets/video_tile.dart';
import '../widgets/waiting_admission_dialog.dart';
import '../widgets/xomm_button.dart';

class MeetingScreen extends StatefulWidget {
  final Meeting meeting;
  final String userId;
  final String userName;
  final bool isHost;
  final bool initialAudioMuted;
  final bool initialVideoMuted;
  final WebRTCService? existingWebRTCService;

  const MeetingScreen({
    super.key,
    required this.meeting,
    required this.userId,
    required this.userName,
    this.isHost = false,
    this.initialAudioMuted = false,
    this.initialVideoMuted = false,
    this.existingWebRTCService,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late final WebRTCService _webrtcService;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();

  StreamSubscription<List<JoinRequest>>? _waitingRoomSubscription;
  StreamSubscription<List<Participant>>? _participantsSubscription;
  StreamSubscription<List<ChatMessage>>? _chatSubscription;
  StreamSubscription<Meeting?>? _meetingSubscription;
  bool _hasHandledEnd = false;

  bool get _isHost =>
      widget.isHost ||
      (widget.meeting.hostId.isNotEmpty && widget.meeting.hostId == widget.userId);

  List<JoinRequest> _pendingRequests = [];
  List<Participant> _participants = [];
  List<ChatMessage> _messages = [];

  bool _isSidePanelOpen = false;
  int _activeSidePanelTab = 0; // 0: Waiting Room, 1: Participants, 2: Chat
  bool _isMediaReady = false;
  bool _isSingleView = false; // false = Multiview (Grid), true = Single View (Focus)
  String? _focusedParticipantId; // null = self, or remote participant.id

  @override
  void initState() {
    super.initState();
    _webrtcService = widget.existingWebRTCService ?? WebRTCService();
    _chatFocusNode.addListener(() {
      if (_chatFocusNode.hasFocus) {
        _scrollToBottom();
      }
    });
    _initMediaAndStreams();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initMediaAndStreams() async {
    try {
      if (!_webrtcService.isInitialized || _webrtcService.localStream == null) {
        await _webrtcService.initLocalStream(
          startWithVideo: !widget.initialVideoMuted,
          startWithAudio: !widget.initialAudioMuted,
        );
      } else {
        _webrtcService.setVideoMute(widget.initialVideoMuted);
        _webrtcService.setAudioMute(widget.initialAudioMuted);
      }
      if (mounted) setState(() => _isMediaReady = true);

      // Start WebRTC P2P Signaling over Firestore (SDP offer/answer and ICE candidates)
      await _webrtcService.startSignaling(
        meetingId: widget.meeting.id,
        userId: widget.userId,
        isHost: _isHost,
        onStreamChanged: () {
          if (mounted) setState(() {});
        },
      );

      // Sync initial media state to participant record
      MeetingService.instance.updateParticipantMedia(
        meetingId: widget.meeting.id,
        userId: widget.userId,
        isAudioMuted: _webrtcService.isAudioMuted,
        isVideoMuted: _webrtcService.isVideoMuted,
      );

      // Watch participants and synchronize WebRTC mesh
      _participantsSubscription = MeetingService.instance
          .watchParticipants(widget.meeting.id)
          .listen((list) {
        if (mounted) {
          setState(() => _participants = list);
          final remoteIds = list
              .where((p) => p.id != widget.userId)
              .map((p) => p.id)
              .toList();
          _webrtcService.syncParticipants(remoteIds);
        }
      });

      // If host: watch waiting room
      if (_isHost) {
        _waitingRoomSubscription = MeetingService.instance
            .watchWaitingRoom(widget.meeting.id)
            .listen((list) {
          if (mounted) setState(() => _pendingRequests = list);
        });
      }

      // Watch chat
      _chatSubscription = MeetingService.instance
          .watchChat(widget.meeting.id)
          .listen((list) {
        if (mounted) {
          setState(() => _messages = list);
          _scrollToBottom();
        }
      });

      // Watch meeting status (automatically redirects everyone if meeting is ended)
      _meetingSubscription = MeetingService.instance
          .watchMeeting(widget.meeting.id)
          .listen((meeting) {
        if (!mounted || _hasHandledEnd) return;
        if (meeting == null || meeting.isEnded) {
          _handleMeetingEnded();
        }
      });
    } catch (e, stack) {
      debugPrint('[MeetingScreen] Error in _initMediaAndStreams: $e\n$stack');
    }
  }

  void _handleMeetingEnded() {
    if (_hasHandledEnd) return;
    _hasHandledEnd = true;

    // Immediately stop camera, microphone, and WebRTC mesh
    _webrtcService.dispose();

    // Cancel all listeners
    _meetingSubscription?.cancel();
    _participantsSubscription?.cancel();
    _waitingRoomSubscription?.cancel();
    _chatSubscription?.cancel();

    if (!mounted) return;

    // Automatically navigate back to Home Screen
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Show clear notification banner on Home Screen
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

  @override
  void dispose() {
    _meetingSubscription?.cancel();
    _waitingRoomSubscription?.cancel();
    _participantsSubscription?.cancel();
    _chatSubscription?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _chatFocusNode.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  void _handleLeave() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentDanger.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: AppTheme.accentDanger,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isHost ? 'End Meeting?' : 'Leave Meeting?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _isHost
                      ? 'Do you want to end the meeting for all participants or just leave the room?'
                      : 'Are you sure you want to leave this meeting?',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (_isHost) ...[
                  XommButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await MeetingService.instance.endMeeting(
                        widget.meeting.id,
                        requesterId: widget.userId,
                      );
                      if (mounted) {
                        _handleMeetingEnded();
                      }
                    },
                    variant: XommButtonVariant.danger,
                    height: 46,
                    text: 'End Meeting for All',
                    icon: Icons.power_settings_new_rounded,
                  ),
                  const SizedBox(height: 10),
                  XommButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await MeetingService.instance.leaveMeeting(widget.meeting.id, widget.userId);
                      if (mounted) {
                        _webrtcService.dispose();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                    variant: XommButtonVariant.secondary,
                    height: 46,
                    text: 'Leave Meeting',
                    icon: Icons.logout_rounded,
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  XommButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await MeetingService.instance.leaveMeeting(widget.meeting.id, widget.userId);
                      if (mounted) {
                        _webrtcService.dispose();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                    variant: XommButtonVariant.danger,
                    height: 46,
                    text: 'Leave Meeting',
                    icon: Icons.logout_rounded,
                  ),
                  const SizedBox(height: 10),
                ],
                XommButton(
                  onPressed: () => Navigator.pop(ctx),
                  variant: XommButtonVariant.glass,
                  height: 42,
                  text: 'Cancel',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    MeetingService.instance.sendMessage(
      widget.meeting.id,
      widget.userId,
      widget.userName,
      text,
    );
    _chatController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 920;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final availableHeight = screenHeight - keyboardHeight - topPadding - 16;
    final sheetHeight = isKeyboardOpen
        ? availableHeight.clamp(280.0, screenHeight * 0.85)
        : (screenHeight * 0.72).clamp(340.0, 720.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isSidePanelOpen) {
            setState(() => _isSidePanelOpen = false);
          } else {
            _handleLeave();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        resizeToAvoidBottomInset: false,
        body: Stack(
        children: [
          // Main Stage (Top Bar + Video Grid + Floating Controls)
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(child: _buildVideoGrid()),
                      _buildControlBar(),
                    ],
                  ),
                ),

                // Desktop Persistent / Toggleable Side Panel
                if (isDesktop && _isSidePanelOpen)
                  Container(
                    width: 340,
                    margin: EdgeInsets.only(
                      top: 12,
                      right: 12,
                      bottom: 12 + keyboardHeight,
                    ),
                    child: _buildSidePanelContent(isBottomSheet: false),
                  ),
              ],
            ),
          ),

          // Top Floating Admission Toast / Alert for Host
          if (_isHost && _pendingRequests.isNotEmpty)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: WaitingAdmissionBanner(
                    request: _pendingRequests.first,
                    onAccept: () {
                      MeetingService.instance.acceptParticipant(
                        widget.meeting.id,
                        _pendingRequests.first.id,
                      );
                    },
                    onReject: () {
                      MeetingService.instance.rejectParticipant(
                        widget.meeting.id,
                        _pendingRequests.first.id,
                      );
                    },
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.5, end: 0),
                ),
              ),
            ),

          // Mobile & Tablet Modal Bottom Sheet for Side Panel
          if (!isDesktop && _isSidePanelOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _isSidePanelOpen = false);
                },
                child: Container(
                  color: Colors.black.withOpacity(0.72),
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // prevent dismissing when tapping inside the sheet
                    child: AnimatedPadding(
                      padding: EdgeInsets.only(bottom: keyboardHeight),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutQuad,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 600, // Sleek, modern card on tablets and full-width on mobile
                        ),
                        child: Container(
                          height: sheetHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.65),
                                blurRadius: 28,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            bottom: !isKeyboardOpen,
                            child: _buildSidePanelContent(isBottomSheet: true),
                          ),
                        ),
                      ),
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

  Widget _buildTopBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 520;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 16,
        vertical: isCompact ? 6 : 10,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 6 : 8),
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.videocam_rounded, color: Colors.white, size: isCompact ? 16 : 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.meeting.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isCompact ? 'P2P Encrypted' : 'Full HD • P2P Encrypted',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Meeting Code pill with 1-tap copy
          MeetingCodePill(code: widget.meeting.code, fontSize: isCompact ? 11 : 13),
          const SizedBox(width: 4),

          // View Mode Switcher (Grid / Multi-View vs Single / Focus View)
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: _isSingleView
                  ? AppTheme.primaryCyan.withOpacity(0.18)
                  : AppTheme.surfaceLighter.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isSingleView
                    ? AppTheme.primaryCyan.withOpacity(0.5)
                    : Colors.white12,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _isSingleView = !_isSingleView;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSingleView ? Icons.grid_view_rounded : Icons.crop_portrait_rounded,
                        color: _isSingleView ? AppTheme.primaryCyan : Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isSingleView ? 'Grid' : 'Single',
                        style: TextStyle(
                          color: _isSingleView ? AppTheme.primaryCyan : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Share Button
          IconButton(
            tooltip: 'Share Invite',
            icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 19),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              Share.share('Join my Xomm video meeting! Code: ${widget.meeting.code}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    // 1. Deduplicate participants strictly by userId (NEVER drop identical names like 'Guest')
    final seen = <String>{};
    final otherParticipants = <Participant>[];

    for (final p in _participants) {
      if (p.id != widget.userId && !seen.contains(p.id)) {
        seen.add(p.id);
        otherParticipants.add(p);
      }
    }

    final totalCount = 1 + otherParticipants.length;
    final isMobile = MediaQuery.of(context).size.width < 640;

    // Helper to build tile for self
    Widget buildLocalTile({VoidCallback? onTap, bool showTapHint = false}) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: VideoTile(
                participantName: widget.userName,
                isHost: _isHost,
                isLocal: true,
                isAudioMuted: _webrtcService.isAudioMuted,
                isVideoMuted: _webrtcService.isVideoMuted,
                isScreenSharing: _webrtcService.isScreenSharing,
                renderer: _isMediaReady ? _webrtcService.localRenderer : null,
              ),
            ),
          ),
          if (showTapHint)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Tap to Focus',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ),
            ),
        ],
      );
    }

    // Helper to build tile for remote participant
    Widget buildRemoteTile(Participant p, {VoidCallback? onTap, bool showTapHint = false}) {
      final rRenderer = _webrtcService.getRendererForPeer(p.id);
      final hasRemoteMedia = rRenderer != null && rRenderer.srcObject != null;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: VideoTile(
                participantName: p.name,
                isHost: p.isHost,
                isLocal: false,
                isAudioMuted: p.isAudioMuted,
                isVideoMuted: p.isVideoMuted,
                isScreenSharing: p.isScreenSharing,
                renderer: hasRemoteMedia ? rRenderer : null,
              ),
            ),
          ),
          if (showTapHint)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Tap to Focus',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ),
            ),
        ],
      );
    }

    // --- CASE A: Solo user in room ---
    if (otherParticipants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: buildLocalTile(),
      );
    }

    // --- CASE B: SINGLE VIEW (Focus / Speaker Mode) ---
    if (_isSingleView) {
      // Find the focused participant or fallback to the first remote
      Participant? focusedParticipant;
      final isFocusingSelf = _focusedParticipantId == widget.userId ||
          (_focusedParticipantId == null && otherParticipants.isEmpty);

      if (!isFocusingSelf) {
        focusedParticipant = otherParticipants.firstWhere(
          (p) => p.id == _focusedParticipantId,
          orElse: () => otherParticipants.first,
        );
      }

      final activeFocusId = isFocusingSelf ? widget.userId : focusedParticipant!.id;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            // Main Stage: Large Focused Video
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: isFocusingSelf
                          ? buildLocalTile()
                          : buildRemoteTile(focusedParticipant!),
                    ),
                    // Badge indicating Single View
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crop_portrait_rounded, color: AppTheme.primaryCyan, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Single Focus',
                              style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Horizontal Carousel of All Joined Participants
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: totalCount,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelf = index == 0;
                  final itemId = isSelf ? widget.userId : otherParticipants[index - 1].id;
                  final isSelected = itemId == activeFocusId;

                  Widget childTile = isSelf
                      ? buildLocalTile()
                      : buildRemoteTile(otherParticipants[index - 1]);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _focusedParticipantId = itemId;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 88,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryCyan : Colors.white24,
                          width: isSelected ? 2.2 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryCyan.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: childTile,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // --- CASE C: MULTIVIEW (Group Video Call Grid - Default) ---
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // Special mobile layout for 2 participants: 2 clean stacked half-screen tiles
          if (isMobile && totalCount == 2) {
            return Column(
              children: [
                Expanded(
                  child: buildLocalTile(
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = widget.userId;
                    }),
                    showTapHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: buildRemoteTile(
                    otherParticipants.first,
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = otherParticipants.first.id;
                    }),
                    showTapHint: true,
                  ),
                ),
              ],
            );
          }

          // Special desktop/tablet layout for 2 participants: 2 balanced half-screen tiles filling the stage
          if (!isMobile && totalCount == 2) {
            return Row(
              children: [
                Expanded(
                  child: buildLocalTile(
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = widget.userId;
                    }),
                    showTapHint: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildRemoteTile(
                    otherParticipants.first,
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = otherParticipants.first.id;
                    }),
                    showTapHint: true,
                  ),
                ),
              ],
            );
          }

          // Special mobile layout for 3 participants: 1 top, 2 bottom
          if (isMobile && totalCount == 3) {
            return Column(
              children: [
                Expanded(
                  flex: 5,
                  child: buildLocalTile(
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = widget.userId;
                    }),
                    showTapHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Expanded(
                        child: buildRemoteTile(
                          otherParticipants[0],
                          onTap: () => setState(() {
                            _isSingleView = true;
                            _focusedParticipantId = otherParticipants[0].id;
                          }),
                          showTapHint: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: buildRemoteTile(
                          otherParticipants[1],
                          onTap: () => setState(() {
                            _isSingleView = true;
                            _focusedParticipantId = otherParticipants[1].id;
                          }),
                          showTapHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Special desktop layout for 3 participants when wide enough: 3 columns side-by-side
          if (!isMobile && totalCount == 3 && constraints.maxWidth > 960) {
            return Row(
              children: [
                Expanded(
                  child: buildLocalTile(
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = widget.userId;
                    }),
                    showTapHint: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildRemoteTile(
                    otherParticipants[0],
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = otherParticipants[0].id;
                    }),
                    showTapHint: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: buildRemoteTile(
                    otherParticipants[1],
                    onTap: () => setState(() {
                      _isSingleView = true;
                      _focusedParticipantId = otherParticipants[1].id;
                    }),
                    showTapHint: true,
                  ),
                ),
              ],
            );
          }

          // 4+ participants or desktop grid: Responsive Grid with dynamic aspect ratio
          int crossAxisCount = 2;
          if (constraints.maxWidth > 900 && totalCount > 2) {
            crossAxisCount = totalCount <= 4 ? 2 : 3;
          } else if (constraints.maxWidth < 600) {
            crossAxisCount = 2;
          }

          final rowCount = (totalCount / crossAxisCount).ceil();
          final availableTileWidth = (constraints.maxWidth - (crossAxisCount - 1) * 8) / crossAxisCount;
          final availableTileHeight = constraints.maxHeight > 0
              ? (constraints.maxHeight - (rowCount - 1) * 8) / rowCount
              : 0.0;
          final aspectRatio = (availableTileHeight > 100 && availableTileWidth > 100)
              ? (availableTileWidth / availableTileHeight).clamp(1.0, 1.85)
              : (isMobile ? 1.0 : (16 / 10));

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: aspectRatio,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return buildLocalTile(
                  onTap: () => setState(() {
                    _isSingleView = true;
                    _focusedParticipantId = widget.userId;
                  }),
                  showTapHint: true,
                );
              } else {
                final p = otherParticipants[index - 1];
                return buildRemoteTile(
                  p,
                  onTap: () => setState(() {
                    _isSingleView = true;
                    _focusedParticipantId = p.id;
                  }),
                  showTapHint: true,
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Center(
        child: ControlDock(
          isAudioMuted: _webrtcService.isAudioMuted,
          isVideoMuted: _webrtcService.isVideoMuted,
          isScreenSharing: _webrtcService.isScreenSharing,
          pendingWaitingRoomCount: _pendingRequests.length,
          participantCount: _participants.length,
          onToggleAudio: () {
            setState(() {
              final isMuted = _webrtcService.toggleAudio();
              MeetingService.instance.updateParticipantMedia(
                meetingId: widget.meeting.id,
                userId: widget.userId,
                isAudioMuted: isMuted,
              );
            });
          },
          onToggleVideo: () {
            setState(() {
              final isMuted = _webrtcService.toggleVideo();
              MeetingService.instance.updateParticipantMedia(
                meetingId: widget.meeting.id,
                userId: widget.userId,
                isVideoMuted: isMuted,
              );
            });
          },
          onSwitchCamera: () async {
            await _webrtcService.switchCamera();
            if (mounted) setState(() {});
          },
          onToggleScreenShare: () async {
            final active = await _webrtcService.toggleScreenShare(
              onScreenShareEnded: () {
                if (mounted) {
                  setState(() {});
                  MeetingService.instance.updateParticipantMedia(
                    meetingId: widget.meeting.id,
                    userId: widget.userId,
                    isScreenSharing: false,
                  );
                }
              },
            );
            if (mounted) {
              setState(() {});
              MeetingService.instance.updateParticipantMedia(
                meetingId: widget.meeting.id,
                userId: widget.userId,
                isScreenSharing: active,
              );
            }
          },
          onOpenParticipants: () {
            setState(() {
              _activeSidePanelTab = _pendingRequests.isNotEmpty ? 0 : 1;
              _isSidePanelOpen = !_isSidePanelOpen;
            });
          },
          onOpenChat: () {
            setState(() {
              if (_isSidePanelOpen && _activeSidePanelTab == 2) {
                FocusScope.of(context).unfocus();
                _isSidePanelOpen = false;
              } else {
                _activeSidePanelTab = 2;
                _isSidePanelOpen = true;
              }
            });
            _scrollToBottom();
          },
          onLeaveMeeting: _handleLeave,
        ),
      ),
    );
  }

  Widget _buildSidePanelContent({bool isBottomSheet = false}) {
    final content = Column(
      children: [
        if (isBottomSheet) ...[
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
        // Panel Tabs Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isBottomSheet ? 14 : 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton(0, 'Waiting (${_pendingRequests.length})'),
                      const SizedBox(width: 8),
                      _buildTabButton(1, 'People (${_participants.length})'),
                      const SizedBox(width: 8),
                      _buildTabButton(2, 'Chat'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _isSidePanelOpen = false);
                },
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 16),

        // Tab Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isBottomSheet ? 14 : 0),
            child: IndexedStack(
              index: _activeSidePanelTab,
              children: [
                _buildWaitingRoomTab(),
                _buildParticipantsTab(),
                _buildChatTab(),
              ],
            ),
          ),
        ),
      ],
    );

    if (isBottomSheet) {
      return content;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: content,
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _activeSidePanelTab == index;
    return InkWell(
      onTap: () => setState(() => _activeSidePanelTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryCyan.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppTheme.primaryCyan.withOpacity(0.4))
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoomTab() {
    if (_pendingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.accentGreen, size: 36),
            SizedBox(height: 10),
            Text(
              'Waiting Room is Empty',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'When guests ask to join, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isHost && _pendingRequests.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: XommButton(
              onPressed: () {
                MeetingService.instance.acceptAll(widget.meeting.id);
              },
              variant: XommButtonVariant.success,
              height: 38,
              text: 'Admit All (${_pendingRequests.length})',
              icon: Icons.done_all_rounded,
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _pendingRequests.length,
            itemBuilder: (context, index) {
              final req = _pendingRequests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLighter.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryCyan.withOpacity(0.2),
                      child: Text(
                        req.userName.isNotEmpty ? req.userName[0].toUpperCase() : 'G',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        req.userName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_isHost) ...[
                      IconButton(
                        tooltip: 'Decline',
                        icon: const Icon(Icons.close_rounded, color: AppTheme.accentDanger, size: 20),
                        onPressed: () {
                          MeetingService.instance.rejectParticipant(widget.meeting.id, req.id);
                        },
                      ),
                      IconButton(
                        tooltip: 'Admit',
                        icon: const Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 20),
                        onPressed: () {
                          MeetingService.instance.acceptParticipant(widget.meeting.id, req.id);
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsTab() {
    return ListView.builder(
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final p = _participants[index];
        final isMe = p.id == widget.userId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLighter.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.secondaryViolet.withOpacity(0.3),
                child: Text(
                  p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name + (isMe ? ' (You)' : ''),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryViolet.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: AppTheme.secondaryVioletGlow,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                p.isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 16,
                color: p.isAudioMuted ? AppTheme.accentDanger : AppTheme.accentGreen,
              ),
              const SizedBox(width: 8),
              Icon(
                p.isVideoMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                size: 16,
                color: p.isVideoMuted ? AppTheme.accentDanger : AppTheme.primaryCyan,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet.\nSend a message to everyone!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg.senderId == widget.userId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppTheme.primaryCyan.withOpacity(0.2)
                              : AppTheme.surfaceLighter,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMe
                                ? AppTheme.primaryCyan.withOpacity(0.4)
                                : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You' : msg.senderName,
                              style: TextStyle(
                                color: isMe ? AppTheme.primaryCyan : AppTheme.secondaryVioletGlow,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              msg.text,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  focusNode: _chatFocusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.surfaceLighter.withOpacity(0.7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'Send',
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
