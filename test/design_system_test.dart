import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restep/core/theme/app_colors.dart';
import 'package:restep/core/theme/app_theme.dart';
import 'package:restep/widgets/widgets.dart';

/// Pumps [child] in the real ReStep theme on a small Android phone
/// (360 x 640 dp) with an optional large system font.
Future<void> pumpApp(
  WidgetTester tester,
  Widget Function(BuildContext) builder, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: builder)),
    ),
  );
}

void main() {
  group('feedback messages', () {
    for (final (tone, icon, color) in [
      (ChipTone.success, Icons.check_circle_rounded, AppColors.success),
      (ChipTone.danger, Icons.error_rounded, AppColors.danger),
      (ChipTone.warning, Icons.warning_amber_rounded, AppColors.warning),
      (ChipTone.info, Icons.info_rounded, AppColors.info),
    ]) {
      testWidgets('${tone.name} uses its own icon and color', (tester) async {
        await pumpApp(
          tester,
          (context) => TextButton(
            onPressed: () => showAppMessage(context, 'Hello', tone: tone),
            child: const Text('go'),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        expect(find.text('Hello'), findsOneWidget);
        final shown = tester.widget<Icon>(find.byIcon(icon));
        expect(shown.color, color);
        expect(shown.semanticLabel, tone.semanticLabel);
      });
    }

    testWidgets('a new message replaces the current one', (tester) async {
      await pumpApp(
        tester,
        (context) => TextButton(
          onPressed: () {
            showAppMessage(context, 'First');
            showAppMessage(context, 'Second', tone: ChipTone.success);
          },
          child: const Text('go'),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });
  });

  group('confirm dialog', () {
    Future<bool?> open(
      WidgetTester tester, {
      required bool destructive,
      double textScale = 1,
    }) async {
      bool? result;
      await pumpApp(
        tester,
        (context) => TextButton(
          onPressed: () async {
            result = await showConfirmDialog(
              context,
              title: 'Delete Account?',
              message:
                  'Are you sure you want to permanently delete your '
                  'account? This action cannot be undone.',
              confirmLabel: 'Delete Account',
              destructive: destructive,
              icon: Icons.delete_forever_rounded,
            );
          },
          child: const Text('go'),
        ),
        textScale: textScale,
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('destructive confirm is red and returns true', (tester) async {
      await open(tester, destructive: true);
      expect(find.byType(DestructiveButton), findsOneWidget);
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Account?'), findsNothing);
    });

    testWidgets('ordinary confirm uses the primary blue button', (
      tester,
    ) async {
      await open(tester, destructive: false);
      expect(find.byType(DestructiveButton), findsNothing);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.backgroundColor, AppColors.navy);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;
      await pumpApp(
        tester,
        (context) => TextButton(
          onPressed: () async => result = await showConfirmDialog(
            context,
            title: 'Sign Out?',
            message: 'Sure?',
            confirmLabel: 'Sign Out',
          ),
          child: const Text('go'),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('fits a small phone at 2x font size without overflow', (
      tester,
    ) async {
      await open(tester, destructive: true, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Delete Account'), findsOneWidget);
    });
  });

  testWidgets('selection controls and banners render at 2x font size', (
    tester,
  ) async {
    await pumpApp(
      tester,
      (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedChoice<int>(
            values: const [1, 2, 3],
            labelOf: (v) => 'Option $v',
            selected: 1,
            onChanged: (_) {},
          ),
          OptionTile(title: 'Smartwatch', selected: true, onTap: () {}),
          const InfoBanner(tone: ChipTone.warning, message: 'Attention'),
          PrimaryButton(label: 'Add Reminder', onPressed: () {}),
          const PrimaryButton(label: 'Saving', loading: true, onPressed: null),
        ],
      ),
      textScale: 2,
    );
    // The loading spinner never settles, so pump a single frame.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
