import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../widgets/adaptive_app_bar.dart';
import 'duo_vertical_bar.dart';

/// Height of the horizontal iOS toolbar below the status bar.
const double kToolbarContentHeight = 44;

AdaptiveScrollEdgeEffectStyle visibleToolbarBackdrop(
  AdaptiveScrollEdgeEffectStyle style, {
  required bool scrolledUnder,
}) => style == AdaptiveScrollEdgeEffectStyle.hard && !scrolledUnder
    ? AdaptiveScrollEdgeEffectStyle.none
    : style;

/// Paints behind the controls within the horizontal toolbar or Duo title band.
class ToolbarBackdrop extends StatelessWidget {
  const ToolbarBackdrop({
    super.key,
    required this.style,
    required this.titleOnly,
  });

  final AdaptiveScrollEdgeEffectStyle style;
  final bool titleOnly;

  @override
  Widget build(BuildContext context) => switch (style) {
    AdaptiveScrollEdgeEffectStyle.none => const SizedBox.shrink(),
    AdaptiveScrollEdgeEffectStyle.soft =>
      titleOnly ? const DuoTitleBackdrop() : const _SoftBackdrop(),
    AdaptiveScrollEdgeEffectStyle.hard => IgnorePointer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground
                  .resolveFrom(context)
                  .withValues(alpha: 0.82),
              border: Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  };
}

/// The soft gradient that keeps the bar readable over scrolling content.
class _SoftBackdrop extends StatelessWidget {
  const _SoftBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final base = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return IgnorePointer(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Container(
          // Runs on below the bar for a smooth fade into the content.
          height:
              MediaQuery.viewPaddingOf(context).top +
              kToolbarContentHeight +
              30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4, 0.7, 1.0],
              colors: [
                base.withValues(alpha: 0.85),
                base.withValues(alpha: 0.6),
                base.withValues(alpha: 0.2),
                base.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
