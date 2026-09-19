import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class MeetingCodePill extends StatefulWidget {
  final String code;
  final bool showCopyButton;
  final double fontSize;

  const MeetingCodePill({
    super.key,
    required this.code,
    this.showCopyButton = true,
    this.fontSize = 15,
  });

  @override
  State<MeetingCodePill> createState() => _MeetingCodePillState();
}

class _MeetingCodePillState extends State<MeetingCodePill> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.code));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 20),
            const SizedBox(width: 10),
            Text(
              'Meeting code "${widget.code}" copied to clipboard!',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceLighter,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.showCopyButton ? _copyToClipboard : null,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLighter.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _copied ? AppTheme.accentGreen.withOpacity(0.5) : AppTheme.primaryCyan.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _copied ? AppTheme.accentGreen : AppTheme.primaryCyan,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_copied ? AppTheme.accentGreen : AppTheme.primaryCyan).withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppTheme.textPrimary,
              ),
            ),
            if (widget.showCopyButton) ...[
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(_copied),
                  size: 16,
                  color: _copied ? AppTheme.accentGreen : AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
