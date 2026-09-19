import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum XommButtonVariant {
  primary,
  secondary,
  glass,
  danger,
  success,
}

class XommButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? text;
  final IconData? icon;
  final XommButtonVariant variant;
  final double? width;
  final double height;
  final bool isLoading;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const XommButton({
    super.key,
    required this.onPressed,
    this.child,
    this.text,
    this.icon,
    this.variant = XommButtonVariant.primary,
    this.width,
    this.height = 52,
    this.isLoading = false,
    this.borderRadius = 16,
    this.padding,
  });

  @override
  State<XommButton> createState() => _XommButtonState();
}

class _XommButtonState extends State<XommButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Gradient? gradient;
    Color? solidColor;
    Border? border;
    List<BoxShadow> shadows = [];

    switch (widget.variant) {
      case XommButtonVariant.primary:
        gradient = AppTheme.brandGradient;
        shadows = [
          BoxShadow(
            color: AppTheme.primaryCyan.withOpacity(_isHovered ? 0.45 : 0.25),
            blurRadius: _isHovered ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case XommButtonVariant.secondary:
        solidColor = AppTheme.surfaceLighter;
        border = Border.all(color: AppTheme.borderGlass, width: 1);
        break;
      case XommButtonVariant.glass:
        solidColor = Colors.white.withOpacity(_isHovered ? 0.12 : 0.06);
        border = Border.all(
          color: Colors.white.withOpacity(_isHovered ? 0.25 : 0.12),
          width: 1,
        );
        break;
      case XommButtonVariant.danger:
        gradient = AppTheme.dangerGradient;
        shadows = [
          BoxShadow(
            color: AppTheme.accentDanger.withOpacity(_isHovered ? 0.45 : 0.25),
            blurRadius: _isHovered ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case XommButtonVariant.success:
        gradient = AppTheme.successGradient;
        shadows = [
          BoxShadow(
            color: AppTheme.accentGreen.withOpacity(_isHovered ? 0.45 : 0.25),
            blurRadius: _isHovered ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ];
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: gradient,
              color: solidColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: border,
              boxShadow: shadows,
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : widget.child ??
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.text != null)
                              Text(
                                widget.text!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                          ],
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
