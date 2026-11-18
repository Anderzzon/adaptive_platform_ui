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
    AdaptiveScrollEdgeEffectStyle.hard => const _HardBackdrop(),
  };
}

class _HardBackdrop extends StatelessWidget {
  const _HardBackdrop();

  // Fixed distances from the lower edge keep the falloff the same on a
  // short Duo title band and on a phone with a tall status bar.
  static const _falloff = [
    (height: 10.0, sigma: 3.2, top: 0.96, bottom: 0.91),
    (height: 10.0, sigma: 1.85, top: 0.91, bottom: 0.78),
    (height: 7.0, sigma: 1.05, top: 0.78, bottom: 0.52),
    (height: 5.0, sigma: 0.55, top: 0.52, bottom: 0.30),
  ];

  @override
  Widget build(BuildContext context) {
    final background = CupertinoColors.systemBackground.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Extend only the paint below the controls. The bar still supplies
          // its usual content inset, and the exposed strip is scrollable.
          Positioned.fill(
            bottom: -12,
            child: ClipRect(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: separator, width: 0),
                  ),
                ),
                child: BackdropGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _blur(
                          5,
                          ColoredBox(
                            color: background.withValues(
                              alpha: _falloff.first.top,
                            ),
                          ),
                        ),
                      ),
                      // Each clip samples the same page. The adjacent tints
                      // meet so the transition is continuous over the text.
                      for (final band in _falloff)
                        SizedBox(
                          height: band.height,
                          child: _blur(
                            band.sigma,
                            _tint(background, band.top, band.bottom),
                          ),
                        ),
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

  Widget _tint(Color color, double top, double bottom) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: top),
          color.withValues(alpha: bottom),
        ],
      ),
    ),
  );

  Widget _blur(double sigma, Widget child) => ClipRect(
    child: BackdropFilter.grouped(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    ),
  );
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
