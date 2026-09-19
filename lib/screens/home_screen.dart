import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meeting_model.dart';
import '../services/meeting_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/meeting_code_pill.dart';
import '../widgets/xomm_button.dart';
import 'meeting_screen.dart';
import 'pre_join_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _hostNameController = TextEditingController(text: 'Host');
  bool _autoAccept = true;
  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    _hostNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateMeeting() async {
    final hostName = _hostNameController.text.trim().isEmpty
        ? 'Host'
        : _hostNameController.text.trim();

    setState(() => _isCreating = true);
    try {
      final hostId = DeviceIdManager.id;
      final meeting = await MeetingService.instance.createMeeting(
        hostId: hostId,
        hostName: hostName,
        autoAccept: _autoAccept,
      );

      if (!mounted) return;
      _showShareDialog(meeting, hostId, hostName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create meeting: $e'),
          backgroundColor: AppTheme.accentDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showShareDialog(Meeting meeting, String hostId, String hostName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: GlassContainer(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
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
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Meeting Ready!',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Share this code with participants to let them join',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                MeetingCodePill(
                  code: meeting.code,
                  fontSize: 18,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _autoAccept ? Icons.check_circle_outline : Icons.lock_outline,
                        size: 15,
                        color: _autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _autoAccept
                              ? 'Auto-Accept is ON (Guests join directly)'
                              : 'Waiting Room Active (You will approve guests)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: XommButton(
                        onPressed: () {
                          Share.share(
                            'Join my Xomm video meeting! Code: ${meeting.code}',
                          );
                        },
                        variant: XommButtonVariant.glass,
                        height: 46,
                        text: 'Share',
                        icon: Icons.share_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: XommButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetingScreen(
                                meeting: meeting,
                                userId: hostId,
                                userName: hostName,
                                isHost: true,
                              ),
                            ),
                          );
                        },
                        variant: XommButtonVariant.primary,
                        height: 46,
                        text: 'Enter Room',
                        icon: Icons.arrow_forward_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleJoinMeeting() async {
    final rawCode = _codeController.text.trim();
    if (rawCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a meeting code'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final meeting = await MeetingService.instance.getMeetingByCode(rawCode);
      if (meeting == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No active meeting found for code "$rawCode"'),
            backgroundColor: AppTheme.accentDanger,
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreJoinScreen(meeting: meeting),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.accentDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 860;

    return Scaffold(
      body: Stack(
        children: [
          // Background ambient lights
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryCyan.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withOpacity(0.15),
                    blurRadius: 160,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryViolet.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryViolet.withOpacity(0.15),
                    blurRadius: 180,
                    spreadRadius: 90,
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header Brand
                      _buildHeader().animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 36),

                      // Interactive Cards Grid
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildCreateCard().animate().fadeIn(delay: 150.ms).slideX(begin: -0.1, end: 0)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildJoinCard().animate().fadeIn(delay: 250.ms).slideX(begin: 0.1, end: 0)),
                          ],
                        )
                      else ...[
                        _buildCreateCard().animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 24),
                        _buildJoinCard().animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
                      ],

                      const SizedBox(height: 40),
                      _buildFeatureBadge().animate().fadeIn(delay: 350.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withOpacity(0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.brandGradient.createShader(bounds),
              child: const Text(
                'XOMM',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Ultra-Fast Full HD Video Meetings with Smart Host Admission',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_to_queue_rounded,
                  color: AppTheme.primaryCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate Meeting',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Host a new instant room',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Host Name Input
          const Text(
            'Your Display Name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hostNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. John Doe',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceLighter.withOpacity(0.5),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary, size: 20),
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
          const SizedBox(height: 20),

          // Auto-Accept Toggle Box (Responsive & sleek custom toggle)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _autoAccept = !_autoAccept),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _autoAccept
                      ? AppTheme.primaryCyan.withOpacity(0.08)
                      : AppTheme.surfaceLighter.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _autoAccept
                        ? AppTheme.primaryCyan.withOpacity(0.4)
                        : Colors.white.withOpacity(0.1),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'Auto-Accept Guests',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: (_autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber)
                                      .withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: (_autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber)
                                        .withOpacity(0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  _autoAccept ? 'Instant' : 'Waiting Room',
                                  style: TextStyle(
                                    color: _autoAccept ? AppTheme.accentGreen : AppTheme.accentAmber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _autoAccept
                                ? 'Anyone with the code enters immediately'
                                : 'Host must approve or reject each guest',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Custom sleek responsive toggle switch
                    GestureDetector(
                      onTap: () => setState(() => _autoAccept = !_autoAccept),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        width: 44,
                        height: 25,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _autoAccept
                              ? AppTheme.primaryCyan
                              : Colors.white.withOpacity(0.15),
                          boxShadow: _autoAccept
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryCyan.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          alignment: _autoAccept
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
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
            ),
          ),
          const SizedBox(height: 24),

          // Generate & Start Button
          XommButton(
            onPressed: _handleCreateMeeting,
            isLoading: _isCreating,
            width: double.infinity,
            variant: XommButtonVariant.primary,
            text: 'Generate Code & Start',
            icon: Icons.rocket_launch_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryViolet.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: AppTheme.secondaryViolet,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join a Meeting',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Enter an existing room code',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),

          const Text(
            'Meeting Code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Code textfield with paste button
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. XOM-842-195',
              hintStyle: const TextStyle(
                color: AppTheme.textMuted,
                letterSpacing: 1,
                fontSize: 15,
              ),
              filled: true,
              fillColor: AppTheme.surfaceLighter.withOpacity(0.5),
              prefixIcon: const Icon(Icons.tag_rounded, color: AppTheme.textSecondary, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Paste from clipboard',
                icon: const Icon(Icons.content_paste_rounded, color: AppTheme.primaryCyan, size: 20),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data != null && data.text != null) {
                    setState(() {
                      _codeController.text = MeetingService.formatCode(data.text!);
                    });
                  }
                },
              ),
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
                borderSide: const BorderSide(color: AppTheme.secondaryViolet),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Info box about waiting room
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLighter.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You will preview your camera & microphone before asking to enter.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 38),

          // Join Button
          XommButton(
            onPressed: _handleJoinMeeting,
            isLoading: _isJoining,
            width: double.infinity,
            variant: XommButtonVariant.secondary,
            text: 'Join Meeting',
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 880;
        if (isMobile) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLighter.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFeatureRowItem(
                  Icons.bolt_rounded,
                  AppTheme.primaryCyan,
                  'Zero Subscriptions Required',
                ),
                const SizedBox(height: 10),
                _buildFeatureRowItem(
                  Icons.hd_rounded,
                  AppTheme.accentGreen,
                  'Full HD P2P Video & Audio',
                ),
                const SizedBox(height: 10),
                _buildFeatureRowItem(
                  Icons.verified_user_rounded,
                  AppTheme.secondaryViolet,
                  'Host Admission Waiting Room',
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLighter.withOpacity(0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFeatureInlineItem(
                Icons.bolt_rounded,
                AppTheme.primaryCyan,
                'Zero Subscriptions Required',
              ),
              _buildFeatureDivider(),
              _buildFeatureInlineItem(
                Icons.hd_rounded,
                AppTheme.accentGreen,
                'Full HD P2P Video & Audio',
              ),
              _buildFeatureDivider(),
              _buildFeatureInlineItem(
                Icons.verified_user_rounded,
                AppTheme.secondaryViolet,
                'Host Admission Waiting Room',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureRowItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureInlineItem(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFeatureDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
