import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/widgets/password_form_field.dart';

void main() {
  group('PasswordFormField', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildField({String? Function(String?)? validator}) {
      return MaterialApp(
        theme: AppTheme.minimal(),
        home: Scaffold(
          body: PasswordFormField(
            controller: controller,
            labelText: 'Mot de passe',
            validator: validator,
          ),
        ),
      );
    }

    testWidgets('renders with label text', (tester) async {
      await tester.pumpWidget(buildField());

      expect(find.text('Mot de passe'), findsOneWidget);
    });

    testWidgets('starts with visibility icon', (tester) async {
      await tester.pumpWidget(buildField());

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('toggles visibility on icon tap', (tester) async {
      await tester.pumpWidget(buildField());

      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      await tester.pumpWidget(buildField());

      await tester.enterText(find.byType(TextFormField), 'secret123');
      await tester.pump();

      expect(controller.text, 'secret123');
    });

    testWidgets('shows custom tooltip labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.minimal(),
          home: Scaffold(
            body: PasswordFormField(
              controller: controller,
              labelText: 'Mot de passe',
              showPasswordTooltip: 'Show',
              hidePasswordTooltip: 'Hide',
            ),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Show');
    });

    testWidgets('has OutlineInputBorder', (tester) async {
      await tester.pumpWidget(buildField());

      final decoration = tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
      expect(decoration.border, isA<OutlineInputBorder>());
    });

    testWidgets('has password autofill hint', (tester) async {
      await tester.pumpWidget(buildField());

      expect(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText == true),
        findsOneWidget,
      );
    });
  });
}
