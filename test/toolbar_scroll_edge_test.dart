import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:adaptive_platform_ui/src/toolbar/toolbar_backdrop.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosted_top_toolbar_test.dart' show hostedApp, inBar, usePhone;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PlatformInfo.debugIOS26OrHigher = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('adaptive_platform_ui/vertical_bar_edge'),
          (_) async => null,
        );
  });
  tearDown(() => PlatformInfo.debugIOS26OrHigher = null);

  const none = AdaptiveScrollEdgeEffectStyle.none;
  const hard = AdaptiveScrollEdgeEffectStyle.hard;
  const soft = AdaptiveScrollEdgeEffectStyle.soft;
  final backdrop = find.byType(ToolbarBackdrop);
  final blur = find.descendant(
    of: backdrop,
    matching: find.byType(BackdropFilter),
  );

  test('the default is soft and copyWith preserves an explicit style', () {
    const bar = AdaptiveAppBar();
    expect(bar.scrollEdgeEffectStyle, soft);
    final clear = bar.copyWith(scrollEdgeEffectStyle: none);
    expect(clear.copyWith(title: 'Title').scrollEdgeEffectStyle, none);
    expect(
      clear.copyWith(scrollEdgeEffectStyle: hard).scrollEdgeEffectStyle,
      hard,
    );
  });

  for (final duo in [false, true]) {
    testWidgets('hosted toolbar follows the page scroll position (Duo: $duo)', (
      tester,
    ) async {
      usePhone(tester);
      if (duo) {
        tester.view.physicalSize = const Size(951, 669);
        tester.view.padding = tester.view.viewPadding = const FakeViewPadding(
          right: 84,
          bottom: 34,
        );
      }
      final style = ValueNotifier(none);
      final scroll = ScrollController();
      addTearDown(style.dispose);
      addTearDown(scroll.dispose);
      var taps = 0;
      var listTaps = 0;
      await tester.pumpWidget(
        hostedApp(
          home: ValueListenableBuilder(
            valueListenable: style,
            builder: (_, value, _) => AdaptiveScaffold(
              appBar: AdaptiveAppBar(
                title: 'Title',
                scrollEdgeEffectStyle: value,
                actions: [
                  AdaptiveAppBarAction(
                    icon: Icons.add,
                    onPressed: () => taps++,
                  ),
                ],
              ),
              body: ListView(
                controller: scroll,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => listTaps++,
                    child: const SizedBox(height: 3000),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The Material widget-test fallback also builds a page-local app bar.
      final action = find.byIcon(Icons.add).hitTestable();
      expect(backdrop, findsNothing);
      await tester.tap(action);
      scroll.jumpTo(140);
      await tester.pumpAndSettle();
      expect(backdrop, findsNothing);
      await tester.tap(action);
      expect(taps, 2);

      style.value = hard;
      await tester.pumpAndSettle();
      expect(tester.widget<ToolbarBackdrop>(backdrop).style, hard);
      expect(tester.widget<ToolbarBackdrop>(backdrop).titleOnly, duo);
      final band = tester.getRect(backdrop);
      expect(band.bottom, duo ? 70 : 106);
      expect(
        tester.getRect(blur),
        Rect.fromLTRB(band.left, band.top, band.right, band.bottom + 12),
      );
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: blur, matching: find.byType(DecoratedBox)),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color!.a, closeTo(0.90, 0.001));
      expect((decoration.border! as Border).bottom.width, 0);
      await tester.tapAt(band.bottomCenter + const Offset(0, 6));
      expect(listTaps, 1);
      expect(scroll.offset, 140);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(backdrop, findsNothing);
      scroll.jumpTo(10);
      await tester.pumpAndSettle();
      expect(backdrop, findsOneWidget);
      style.value = soft;
      await tester.pumpAndSettle();
      expect(tester.widget<ToolbarBackdrop>(backdrop).style, soft);
      style.value = none;
      await tester.pumpAndSettle();
      expect(backdrop, findsNothing);
    });
  }

  testWidgets('cancelling a back swipe restores the clear toolbar', (
    tester,
  ) async {
    usePhone(tester);
    final nav = GlobalKey<NavigatorState>();
    final scroll = ScrollController(initialScrollOffset: 80);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      hostedApp(
        navigatorKey: nav,
        home: AdaptiveScaffold(
          appBar: const AdaptiveAppBar(
            title: 'List',
            scrollEdgeEffectStyle: hard,
          ),
          body: ListView(
            controller: scroll,
            children: const [SizedBox(height: 3000)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(backdrop, findsOneWidget);
    nav.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => const AdaptiveScaffold(
          appBar: AdaptiveAppBar(title: 'Detail', scrollEdgeEffectStyle: none),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(backdrop, findsNothing);
    final gesture = await tester.startGesture(const Offset(4, 300));
    await gesture.moveBy(const Offset(45, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(245, 0));
    await tester.pump();
    final fade = find
        .ancestor(of: backdrop, matching: find.byType(FadeTransition))
        .first;
    expect(
      tester.widget<FadeTransition>(fade).opacity.value,
      inExclusiveRange(0, 1),
    );
    await gesture.moveBy(const Offset(-245, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(inBar(find.text('Detail')), findsOneWidget);
    expect(backdrop, findsNothing);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(backdrop, findsOneWidget);
    expect(scroll.offset, 80);
  });

  for (final hosted in [false, true]) {
    testWidgets(
      'style changes preserve the native view and action channel (hosted: $hosted)',
      (tester) async {
        usePhone(tester);
        final messenger = tester.binding.defaultBinaryMessenger;
        final created = <int>[];
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          final args = call.arguments;
          if (call.method == 'create' &&
              args['viewType'] == 'adaptive_platform_ui/ios26_toolbar') {
            created.add(args['id'] as int);
          }
          return null;
        });
        final style = ValueNotifier(none);
        final scroll = ScrollController();
        addTearDown(style.dispose);
        addTearDown(scroll.dispose);
        var taps = 0;
        final page = ValueListenableBuilder(
          valueListenable: style,
          builder: (_, value, _) {
            final list = ListView(
              controller: scroll,
              children: const [SizedBox(height: 3000)],
            );
            final actions = [
              AdaptiveAppBarAction(iosSymbol: 'plus', onPressed: () => taps++),
            ];
            return AdaptiveScaffold(
              appBar: AdaptiveAppBar(
                title: 'Title',
                actions: actions,
                scrollEdgeEffectStyle: value,
              ),
              body: list,
            );
          },
        );
        await tester.pumpWidget(
          hosted ? hostedApp(home: page) : MaterialApp(home: page),
        );
        await tester.pumpAndSettle();
        final native = find.byWidgetPredicate(
          (w) =>
              w is UiKitView &&
              w.viewType == 'adaptive_platform_ui/ios26_toolbar',
        );
        final view = tester.element(native);
        final controls = tester.getRect(native);
        expect(
          (tester.widget<UiKitView>(native).creationParams
              as Map)['showsGradient'],
          false,
        );
        Future<void> tapAction() => messenger.handlePlatformMessage(
          'adaptive_platform_ui/ios26_toolbar_${created.single}',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onActionTapped', {'index': 0}),
          ),
          (_) {},
        );
        await tapAction();
        scroll.jumpTo(100);
        await tester.pumpAndSettle();
        expect(backdrop, findsNothing);
        await tapAction();
        style.value = hard;
        await tester.pumpAndSettle();
        expect(backdrop, findsOneWidget);
        expect(tester.getRect(native), controls);
        expect(tester.getRect(blur).bottom, controls.bottom + 12);
        expect(tester.element(native), same(view));
        style.value = none;
        await tester.pumpAndSettle();
        expect(backdrop, findsNothing);
        await tapAction();
        expect(taps, 3);
        expect(created, hasLength(1));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
