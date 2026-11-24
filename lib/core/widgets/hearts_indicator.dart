import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// Five-heart indicator with shrink animation and subtle red flash when a heart is lost.
class HeartsIndicator extends StatefulWidget {
  const HeartsIndicator({
    super.key,
    required this.hearts,
    this.maxHearts = AppConstants.startingHearts,
    this.size = 20,
    this.label,
  });

  final int hearts;
  final int maxHearts;
  final double size;
  final String? label;

  @override
  State<HeartsIndicator> createState() => _HeartsIndicatorState();
}

class _HeartsIndicatorState extends State<HeartsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 65),
    ]).animate(_flashController);
  }

  @override
  void didUpdateWidget(covariant HeartsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hearts < oldWidget.hearts) {
      _flashController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.cardBackground.withValues(alpha: 0.75),
              AppColors.danger.withValues(alpha: 0.38),
              _flashAnimation.value,
            ),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: Color.lerp(
                AppColors.borderSubtle,
                AppColors.danger,
                _flashAnimation.value,
              )!,
            ),
          ),
          child: child,
        );
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
            ],
            ...List.generate(widget.maxHearts, (index) {
              final filled = index < widget.hearts;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AnimatedScale(
                  scale: filled ? 1.0 : 0.72,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    filled
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: widget.size,
                    color: filled
                        ? AppColors.danger
                        : AppColors.textMuted.withValues(alpha: 0.45),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
