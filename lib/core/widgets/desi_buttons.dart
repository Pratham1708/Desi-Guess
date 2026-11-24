import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Animated gradient primary action button.
class DesiPrimaryButton extends StatefulWidget {
  const DesiPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient = AppColors.primaryButtonGradient,
    this.fullWidth = true,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Gradient gradient;
  final bool fullWidth;
  final double height;

  @override
  State<DesiPrimaryButton> createState() => _DesiPrimaryButtonState();
}

class _DesiPrimaryButtonState extends State<DesiPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: SizedBox(
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: enabled
                  ? widget.gradient
                  : LinearGradient(
                      colors: [
                        AppColors.borderSubtle,
                        AppColors.borderSubtle.withValues(alpha: 0.7),
                      ],
                    ),
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.primaryAccent.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? widget.onPressed : null,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: Text(
                                  widget.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 15,
                                        letterSpacing: 0.4,
                                      ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined glassmorphic secondary button.
class DesiSecondaryButton extends StatelessWidget {
  const DesiSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.borderColor,
    this.fullWidth = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? borderColor;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        borderColor ?? AppColors.secondaryAccent.withValues(alpha: 0.45);
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: effectiveBorder, width: 1.3),
          backgroundColor: AppColors.cardBackground.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: AppColors.secondaryAccent),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
