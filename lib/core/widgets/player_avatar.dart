import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Curated stylized player avatar widget.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.avatarId,
    this.displayName = '',
    this.size = 44,
    this.isActiveTurn = false,
    this.isOnline,
  });

  final String avatarId;
  final String displayName;
  final double size;
  final bool isActiveTurn;
  final bool? isOnline;

  static const List<({String id, Color color, IconData icon, String label})>
  presets = [
    (
      id: 'avatar_1',
      color: Color(0xFF8B5CF6),
      icon: Icons.bolt_rounded,
      label: 'Electric',
    ),
    (
      id: 'avatar_2',
      color: Color(0xFFFF9933),
      icon: Icons.local_fire_department_rounded,
      label: 'Saffron',
    ),
    (
      id: 'avatar_3',
      color: Color(0xFF2DD4BF),
      icon: Icons.diamond_rounded,
      label: 'Turquoise',
    ),
    (
      id: 'avatar_4',
      color: Color(0xFFEC4899),
      icon: Icons.auto_awesome_rounded,
      label: 'Star',
    ),
    (
      id: 'avatar_5',
      color: Color(0xFF22C55E),
      icon: Icons.sports_cricket_rounded,
      label: 'Striker',
    ),
    (
      id: 'avatar_6',
      color: Color(0xFFFBBF24),
      icon: Icons.workspace_premium_rounded,
      label: 'Maharaja',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final preset = presets.firstWhere(
      (p) => p.id == avatarId,
      orElse: () => presets.first,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [preset.color, preset.color.withValues(alpha: 0.45)],
            ),
            border: Border.all(
              color: isActiveTurn
                  ? AppColors.saffronAccent
                  : Colors.white.withValues(alpha: 0.22),
              width: isActiveTurn ? 2.5 : 1.4,
            ),
            boxShadow: isActiveTurn
                ? [
                    BoxShadow(
                      color: AppColors.saffronAccent.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(preset.icon, color: Colors.white, size: size * 0.5),
        ),
        if (isOnline != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline! ? AppColors.success : AppColors.textMuted,
                border: Border.all(
                  color: AppColors.primaryBackground,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
