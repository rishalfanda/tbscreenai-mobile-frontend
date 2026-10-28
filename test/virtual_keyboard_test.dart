import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/virtual_keyboard/application/virtual_keyboard_bridge.dart';
import 'package:myapp/features/virtual_keyboard/application/virtual_keyboard_controller.dart';
import 'package:myapp/features/virtual_keyboard/presentation/virtual_keyboard_host.dart';
import 'package:myapp/features/virtual_keyboard/presentation/virtual_keyboard_key.dart';
import 'package:myapp/features/virtual_keyboard/presentation/virtual_keyboard_view.dart';

void main() {
  group('VirtualKeyboardBridge', () {
    testWidgets('inserts text at cursor and replaces selections', (tester) async {
      final controller = TextEditingController(text: 'Hello');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Insert character '!' at end
      VirtualKeyboardBridge.insertText('!');
      await tester.pump();
      expect(controller.text, 'Hello!');

      // Set selection to replace 'ello'
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 5);
      VirtualKeyboardBridge.insertText('i');
      await tester.pump();
      expect(controller.text, 'Hi!');
    });

    testWidgets('backspace removes preceding char or selection', (tester) async {
      final controller = TextEditingController(text: 'Testing');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Backspace at end removes 'g'
      controller.selection = const TextSelection.collapsed(offset: 7);
      VirtualKeyboardBridge.backspace();
      await tester.pump();
      expect(controller.text, 'Testin');

      // Backspace on selection 'est' removes selection
      controller.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
      VirtualKeyboardBridge.backspace();
      await tester.pump();
      expect(controller.text, 'Tin');
    });

    testWidgets('space and clear work properly', (tester) async {
      final controller = TextEditingController(text: 'Word');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      VirtualKeyboardBridge.space();
      await tester.pump();
      expect(controller.text, 'Word ');

      VirtualKeyboardBridge.clear();
      await tester.pump();
      expect(controller.text, '');
    });

    testWidgets('submit triggers onSubmitted for single-line field', (tester) async {
      String? submittedText;
      final controller = TextEditingController(text: 'FinalText');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              onSubmitted: (val) => submittedText = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      VirtualKeyboardBridge.submit();
      await tester.pump();
      expect(submittedText, 'FinalText');
    });
  });

  group('VirtualKeyboardController', () {
    test('manages mode switching, shift, and caps lock', () {
      final controller = VirtualKeyboardController();

      expect(controller.mode, VirtualKeyboardMode.alphanumeric);
      expect(controller.isShifted, false);
      expect(controller.isCapsLock, false);

      controller.toggleShift();
      expect(controller.isShifted, true);

      controller.onCharacterTyped();
      expect(controller.isShifted, false);

      controller.toggleCapsLock();
      expect(controller.isCapsLock, true);
      expect(controller.isShifted, true);

      // Typing with caps lock keeps it shifted
      controller.onCharacterTyped();
      expect(controller.isShifted, true);

      controller.toggleCapsLock();
      expect(controller.isCapsLock, false);
      expect(controller.isShifted, false);

      controller.setMode(VirtualKeyboardMode.symbols);
      expect(controller.mode, VirtualKeyboardMode.symbols);

      controller.dispose();
    });
  });

  group('VirtualKeyboardHost and VirtualKeyboardView', () {
    testWidgets('shows virtual keyboard when TextField is focused on supported platform', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: VirtualKeyboardHost(
            enableOnAllPlatforms: true,
            child: Scaffold(
              body: TextField(controller: controller),
            ),
          ),
        ),
      );

      // Initially, no keyboard is visible
      expect(find.byType(VirtualKeyboardView), findsNothing);

      // Tap TextField to focus
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pumpAndSettle();

      // Keyboard appears
      expect(find.byType(VirtualKeyboardView), findsOneWidget);

      // Tap letter 'a' on virtual keyboard
      final keyA = find.widgetWithText(VirtualKeyboardKey, 'a');
      expect(keyA, findsOneWidget);
      await tester.tap(keyA);
      await tester.pump();

      expect(controller.text, 'a');

      // Tap 'Sembunyikan' to dismiss
      await tester.tap(find.text('Sembunyikan'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(VirtualKeyboardView), findsNothing);
      // Floating button appears since input is still focused
      expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);

      // Tap floating button to reopen
      await tester.tap(find.byIcon(Icons.keyboard_rounded));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(VirtualKeyboardView), findsOneWidget);
    });

    testWidgets('automatically selects numeric layout for number inputs', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: VirtualKeyboardHost(
            enableOnAllPlatforms: true,
            child: Scaffold(
              body: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pumpAndSettle();

      // Numeric mode layout is active, should show 'Clear' button
      expect(find.text('Clear'), findsOneWidget);

      // Tap number 7
      await tester.tap(find.widgetWithText(VirtualKeyboardKey, '7'));
      await tester.pump();
      expect(controller.text, '7');
    });

    testWidgets('continuous typing on virtual keyboard keeps keyboard open', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: VirtualKeyboardHost(
            enableOnAllPlatforms: true,
            child: Scaffold(
              body: TextField(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byType(VirtualKeyboardView), findsOneWidget);

      // Tap multiple keys: 'h', 'e', 'l', 'l', 'o'
      for (final char in ['h', 'e', 'l', 'l', 'o']) {
        final key = find.widgetWithText(VirtualKeyboardKey, char);
        expect(key, findsOneWidget);
        await tester.tap(key);
        await tester.pump();
      }

      expect(controller.text, 'hello');
      // Virtual keyboard remains open throughout typing
      expect(find.byType(VirtualKeyboardView), findsOneWidget);
    });
  });
}

