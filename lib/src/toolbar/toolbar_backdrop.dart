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

  @override
  Widget build(BuildContext context) {
    final background = CupertinoColors.systemBackground.resolveFrom(context);
    final bottomOpacity =
        CupertinoTheme.brightnessOf(context) == Brightness.dark ? 0.40 : 0.30;
    final separator = CupertinoColors.opaqueSeparator.resolveFrom(context);
    final pixel = 1 / MediaQuery.devicePixelRatioOf(context);
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
                    // A zero-width stroke sits on the clip boundary. Place
                    // the entire physical pixel inside the backdrop.
                    bottom: BorderSide(color: separator, width: pixel),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 0.55, sigmaY: 0.55),
                      child: const SizedBox.expand(),
                    ),
                    // Gaussian variances add. Over the lightly blurred page,
                    // this second pass gives a 2.4-point blur behind the title.
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2.34, sigmaY: 2.34),
                      child: CustomPaint(
                        painter: _HardEdgeFalloff(background, bottomOpacity),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HardEdgeFalloff extends CustomPainter {
  _HardEdgeFalloff(Color background, double bottomOpacity)
    : _tint = _gradient(
        background,
        (t) => _topOpacity + (bottomOpacity - _topOpacity) * t * t * t,
      );

  final LinearGradient _tint;
  static const _topOpacity = 0.80;
  static const _height = 32.0;
  static const _intervals = 16;
  static final _blurMask = _gradient(
    const Color(0xFFFFFFFF),
    (t) => 1 - t * t * (3 - 2 * t),
  );

  static LinearGradient _gradient(
    Color color,
    double Function(double) opacityAt,
  ) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: List.generate(
      _intervals + 1,
      (i) => color.withValues(alpha: opacityAt(i / _intervals)),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final falloff = Rect.fromLTWH(
      0,
      size.height - _height,
      size.width,
      _height,
    );
    // Mask the filtered backdrop in its own layer. At the bottom the
    // lightly blurred page shows through. The two blurs crossfade above it.
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _blurMask.createShader(falloff),
    );
    canvas.drawRect(bounds, Paint()..shader = _tint.createShader(falloff));
  }

  @override
  bool shouldRepaint(_HardEdgeFalloff oldDelegate) =>
      _tint != oldDelegate._tint;
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
