import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Original DESI GUESS brand logo widget combining our custom emblem and typography.
class DesiLogo extends StatelessWidget {
  const DesiLogo({
    super.key,
    this.size = 44,
    this.showWordmark = true,
    this.showTagline = false,
  });

  final double size;
  final bool showWordmark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryAccent.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.secondaryAccent.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/icons/app_icon.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryButtonGradient,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.help_outline_rounded,
                color: Colors.white,
                size: size * 0.56,
              ),
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    fontSize: size * 0.46,
                  ),
                  children: const [
                    TextSpan(text: 'DESI '),
                    TextSpan(
                      text: 'GUESS',
                      style: TextStyle(color: AppColors.saffronAccent),
                    ),
                  ],
                ),
              ),
              if (showTagline)
                Text(
                  'WHO • WHAT • WHERE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.turquoiseAccent,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
