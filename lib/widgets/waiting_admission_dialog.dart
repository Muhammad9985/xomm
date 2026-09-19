import 'package:flutter/material.dart';
import '../models/meeting_model.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';
import 'xomm_button.dart';

class WaitingAdmissionBanner extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const WaitingAdmissionBanner({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: AppTheme.accentAmber.withOpacity(0.15),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.secondaryViolet.withOpacity(0.3),
            child: Text(
              request.userName.isNotEmpty ? request.userName[0].toUpperCase() : 'G',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        request.userName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Waiting Room',
                        style: TextStyle(
                          color: AppTheme.accentAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'wants to enter the meeting',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              XommButton(
                onPressed: onReject,
                variant: XommButtonVariant.glass,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                borderRadius: 10,
                child: const Row(
                  children: [
                    Icon(Icons.close_rounded, size: 16, color: AppTheme.accentDanger),
                    SizedBox(width: 4),
                    Text(
                      'Decline',
                      style: TextStyle(
                        color: AppTheme.accentDanger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              XommButton(
                onPressed: onAccept,
                variant: XommButtonVariant.success,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                borderRadius: 10,
                child: const Row(
                  children: [
                    Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Admit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
