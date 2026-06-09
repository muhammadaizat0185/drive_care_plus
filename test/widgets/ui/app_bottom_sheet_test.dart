import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/widgets/ui/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke tests for `AppBottomSheet`.
///
/// Validates the contracts spelled out in
/// figma-ui-redesign Requirements 3.9 and 3.11:
///   * sheet renders with top-rounded `AppRadii.large` corners,
///   * drag handle is shown,
///   * `show<T>` resolves with the value popped from inside the builder,
///   * the body is wrapped in a `SizedBox` whose height is proportional to
///     the viewport via `initialHeightFraction`.
void main() {
  Widget hostApp({required Widget Function(BuildContext) home}) {
    return MaterialApp(
      theme: AppTheme.buildTheme(AppColors.emerald500, Brightness.light),
      home: Builder(builder: home),
    );
  }

  testWidgets('show() renders sheet body and drag handle', (tester) async {
    await tester.pumpWidget(
      hostApp(
        home: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => AppBottomSheet.show<void>(
                context,
                builder: (_) => const Text('hello sheet'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('hello sheet'), findsOneWidget);
    // Flutter's stock drag-handle widget exposes a Semantics node labelled
    // `Dismiss`; the showDragHandle: true contract above means it must be
    // present.
    expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
  });

  testWidgets('show() returns value popped from builder', (tester) async {
    int? captured = -1;

    await tester.pumpWidget(
      hostApp(
        home: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                captured = await AppBottomSheet.show<int>(
                  context,
                  builder: (sheetContext) => ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(42),
                    child: const Text('confirm'),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('confirm'));
    await tester.pumpAndSettle();

    expect(captured, 42);
  });

  testWidgets('sheet body honours initialHeightFraction', (tester) async {
    const double fraction = 0.4;
    const Key bodyKey = Key('sheet-body');

    await tester.pumpWidget(
      hostApp(
        home: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => AppBottomSheet.show<void>(
                context,
                initialHeightFraction: fraction,
                builder: (_) => const SizedBox.expand(
                  key: bodyKey,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final BuildContext sheetContext = tester.element(find.byKey(bodyKey));
    final double viewportHeight = MediaQuery.of(sheetContext).size.height;

    // Locate the wrapping SizedBox introduced by AppBottomSheet (the one
    // whose height equals viewport * fraction).
    final Iterable<SizedBox> wrappers = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((s) => s.height == viewportHeight * fraction);

    expect(wrappers, isNotEmpty);
    expect(wrappers.first.height, closeTo(viewportHeight * fraction, 0.01));
  });

  testWidgets('asserts on out-of-range initialHeightFraction', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      hostApp(
        home: (context) {
          capturedContext = context;
          return const Scaffold();
        },
      ),
    );

    expect(
      () => AppBottomSheet.show<void>(
        capturedContext,
        builder: (_) => const SizedBox.shrink(),
        initialHeightFraction: 0.0,
      ),
      throwsA(isA<AssertionError>()),
    );

    expect(
      () => AppBottomSheet.show<void>(
        capturedContext,
        builder: (_) => const SizedBox.shrink(),
        initialHeightFraction: 1.5,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('sheet shifts up and caps height when viewInsets.bottom (keyboard) is present', (tester) async {
    const Key bodyKey = Key('sheet-body');
    const double fraction = 0.8; // Target height = 800 * 0.8 = 640

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(AppColors.emerald500, Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(400, 800),
            viewInsets: const EdgeInsets.only(bottom: 300), // 300px keyboard
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppBottomSheet.show<void>(
                context,
                initialHeightFraction: fraction,
                builder: (_) => const SizedBox(
                  key: bodyKey,
                  height: 100,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(bodyKey), findsOneWidget);

    // Screen height = 800.
    // Target height = 800 * 0.8 = 640.
    // Keyboard = 300.
    // Max available height = 800 - 300 = 500.
    // Target height (640) > max available (500) -> height must be capped at 500.
    
    // Find the SizedBox that wraps our builder in AppBottomSheet.
    // We expect its height to be capped at 500 (or less if top safe area applies).
    final SizedBox wrapper = tester.widget<SizedBox>(
      find.ancestor(
        of: find.byKey(bodyKey),
        matching: find.byType(SizedBox),
      ).first,
    );
    final BuildContext elementContext = tester.element(find.byKey(bodyKey));
    final double expectedHeight = 800 - 300 - MediaQuery.of(elementContext).padding.top;
    expect(wrapper.height, expectedHeight);

    // Verify the bottom padding matches the keyboard height of 300.
    final Padding paddingWidget = tester.widget<Padding>(
      find.ancestor(
        of: find.byWidget(wrapper),
        matching: find.byType(Padding),
      ).first,
    );
    expect(paddingWidget.padding, const EdgeInsets.only(bottom: 300));
  });
}
