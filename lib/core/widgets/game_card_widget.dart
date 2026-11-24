import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/game_models.dart';
import '../constants/app_colors.dart';
import '../utils/card_artwork_resolver.dart';

/// Image-first collectible DESI GUESS card supporting all 4 board states:
/// - NORMAL: possible opponent card
/// - MY CARD ([isMySecretCard]): player's own secret card with discreet UI badge
/// - ELIMINATED ([isEliminated]): faded grayscale overlay
/// - SELECTED ([isSelected]): highlighted saffron border
///
/// Never falls back to initials or emojis — displays polished loading & visual
/// error states when an image fails to load.
class GameCardWidget extends StatefulWidget {
  const GameCardWidget({
    super.key,
    required this.card,
    required this.onTap,
    this.onLongPress,
    this.isEliminated = false,
    this.isSelected = false,
    this.isMySecretCard = false,
    this.compact = false,
    this.showDifficulty = true,
  });

  final GameCard card;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isEliminated;
  final bool isSelected;
  final bool isMySecretCard;
  final bool compact;
  final bool showDifficulty;

  @override
  State<GameCardWidget> createState() => _GameCardWidgetState();
}

class _GameCardWidgetState extends State<GameCardWidget> {
  int _retryNonce = 0;

  Color get _accentColor => Color(widget.card.accentHex);

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isSelected
        ? AppColors.saffronAccent
        : widget.isMySecretCard
        ? AppColors.turquoiseAccent
        : widget.isEliminated
        ? AppColors.borderSubtle.withValues(alpha: 0.45)
        : _accentColor.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: widget.isEliminated ? 0.94 : (widget.isSelected ? 1.03 : 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.isEliminated ? 0.36 : 1.0,
          duration: const Duration(milliseconds: 220),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              color: AppColors.cardBackground,
              border: Border.all(
                color: borderColor,
                width: (widget.isSelected || widget.isMySecretCard) ? 2.4 : 1.2,
              ),
              boxShadow: widget.isEliminated
                  ? null
                  : [
                      BoxShadow(
                        color:
                            (widget.isSelected
                                    ? AppColors.saffronAccent
                                    : widget.isMySecretCard
                                    ? AppColors.turquoiseAccent
                                    : _accentColor)
                                .withValues(
                                  alpha:
                                      (widget.isSelected ||
                                          widget.isMySecretCard)
                                      ? 0.38
                                      : 0.18,
                                ),
                        blurRadius: (widget.isSelected || widget.isMySecretCard)
                            ? 16
                            : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary full-width image artwork area (zero baked-in text)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: widget.isEliminated
                            ? const ColorFilter.mode(
                                Color(0xFF334155),
                                BlendMode.saturation,
                              )
                            : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.srcOver,
                              ),
                        child: _buildImageArea(),
                      ),

                      // Subtle top vignette for discreet UI badges
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 44,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primaryBackground.withValues(
                                  alpha: 0.65,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Top-left discreet MY CARD badge (or category pill)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: widget.isMySecretCard
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.turquoiseAccent,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 10,
                                      color: AppColors.primaryBackground,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'MY CARD',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                        color: AppColors.primaryBackground,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBackground.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _accentColor.withValues(alpha: 0.65),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  widget.card.category.displayName,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),

                      if (widget.isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.saffronAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: AppColors.primaryBackground,
                            ),
                          ),
                        ),

                      if (widget.isEliminated)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CrossOutPainter(
                              color: AppColors.danger.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Clean caption strip BELOW the artwork (never baked into image)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 6 : 8,
                    vertical: widget.compact ? 6 : 8,
                  ),
                  color: AppColors.secondaryBackground,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.card.name,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: widget.isEliminated
                                  ? AppColors.textMuted
                                  : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: widget.compact ? 11.5 : 12.5,
                              decoration: widget.isEliminated
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                      ),
                      if (!widget.compact &&
                          widget.card.subcategory.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          widget.card.subcategory,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final localAsset = CardArtworkResolver.assetForCard(widget.card);
    if (CardArtworkResolver.hasRemoteImage(widget.card)) {
      return CachedNetworkImage(
        key: ValueKey('remote_${widget.card.id}_$_retryNonce'),
        imageUrl: widget.card.imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 320,
        memCacheHeight: 320,
        placeholder: (_, _) => _buildLoadingState(),
        errorWidget: (_, _, _) => _buildLocalAsset(localAsset),
      );
    }
    return _buildLocalAsset(localAsset);
  }

  Widget _buildLocalAsset(String assetPath) {
    return Image.asset(
      assetPath,
      key: ValueKey('asset_${assetPath}_$_retryNonce'),
      fit: BoxFit.cover,
      cacheWidth: 320,
      cacheHeight: 320,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return _buildLoadingState();
      },
      errorBuilder: (_, _, _) {
        final fallback = CardArtworkResolver.fallbackForCategory(
          widget.card.category,
        );
        if (assetPath != fallback) {
          return Image.asset(
            fallback,
            fit: BoxFit.cover,
            cacheWidth: 320,
            cacheHeight: 320,
            errorBuilder: (_, _, _) => _buildVisualErrorState(),
          );
        }
        return _buildVisualErrorState();
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBackground,
            _accentColor.withValues(alpha: 0.22),
            AppColors.secondaryBackground,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: _accentColor.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// Visual error state with retry (never uses text initials or emojis).
  Widget _buildVisualErrorState() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.cardSurfaceGradient),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: _accentColor.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _retryNonce++),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrossOutPainter extends CustomPainter {
  const _CrossOutPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossOutPainter oldDelegate) =>
      oldDelegate.color != color;
}
