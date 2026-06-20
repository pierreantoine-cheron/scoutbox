import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/utils/app_colors.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/widgets/fading_cloud_done_icon.dart';

void main() {
  group('FadingCloudDoneIcon', () {
    testWidgets('renders cloud_done icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.minimal(),
          home: const Scaffold(body: FadingCloudDoneIcon(trigger: 0)),
        ),
      );

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('starts invisible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.minimal(),
          home: const Scaffold(body: FadingCloudDoneIcon(trigger: 0)),
        ),
      );

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets('becomes visible when trigger changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.minimal(),
          home: const Scaffold(body: FadingCloudDoneIcon(trigger: 0)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.minimal(),
          home: const Scaffold(body: FadingCloudDoneIcon(trigger: 1)),
        ),
      );

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('icon uses semantic success color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.minimal(),
          home: const Scaffold(body: FadingCloudDoneIcon(trigger: 0)),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, AppColors.success);
    });

    testWidgets('asserts when semantic extension is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FadingCloudDoneIcon(trigger: 0)),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
  });
}
