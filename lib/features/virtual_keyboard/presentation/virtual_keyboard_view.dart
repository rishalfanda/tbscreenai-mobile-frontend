import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/virtual_keyboard/application/virtual_keyboard_bridge.dart';
import 'package:myapp/features/virtual_keyboard/application/virtual_keyboard_controller.dart';
import 'package:myapp/features/virtual_keyboard/presentation/virtual_keyboard_key.dart';

/// The full on-screen virtual keyboard view containing layouts for alphanumeric,
/// numeric, and symbol inputs.
class VirtualKeyboardView extends StatelessWidget {
  const VirtualKeyboardView({
    super.key,
    required this.controller,
  });

  final VirtualKeyboardController controller;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: true,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Material(
            color: const Color(0xFF0B132B), // Deep slate navy
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1020),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: 4),
                          switch (controller.mode) {
                            VirtualKeyboardMode.numeric => _buildNumericLayout(),
                            VirtualKeyboardMode.symbols => _buildSymbolsLayout(),
                            VirtualKeyboardMode.alphanumeric =>
                              _buildAlphanumericLayout(),
                          },
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final mode = controller.mode;
    return Row(
      children: [
        _modeButton(
          label: 'ABC',
          isActive: mode == VirtualKeyboardMode.alphanumeric,
          onTap: () => controller.setMode(VirtualKeyboardMode.alphanumeric),
        ),
        const SizedBox(width: 6),
        _modeButton(
          label: '123',
          isActive: mode == VirtualKeyboardMode.numeric,
          onTap: () => controller.setMode(VirtualKeyboardMode.numeric),
        ),
        const SizedBox(width: 6),
        _modeButton(
          label: '!@#',
          isActive: mode == VirtualKeyboardMode.symbols,
          onTap: () => controller.setMode(VirtualKeyboardMode.symbols),
        ),
        const Spacer(),
        // Quick dismiss button
        TextButton.icon(
          onPressed: () => controller.hide(),
          icon: const Icon(
            Icons.keyboard_hide_rounded,
            color: Colors.white70,
            size: 18,
          ),
          label: const Text(
            'Sembunyikan',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive ? AppTheme.primary : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlphanumericLayout() {
    final shifted = controller.isShifted;

    String char(String lowercase) => shifted ? lowercase.toUpperCase() : lowercase;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Numbers + Backspace
        Row(
          children: [
            for (final n in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
              VirtualKeyboardKey(
                text: n,
                onTap: () {
                  VirtualKeyboardBridge.insertText(n);
                  controller.onCharacterTyped();
                },
              ),
            VirtualKeyboardKey(
              icon: Icons.backspace_outlined,
              flex: 2,
              type: VirtualKeyType.action,
              onTap: VirtualKeyboardBridge.backspace,
            ),
          ],
        ),
        // Row 2: QWERTY
        Row(
          children: [
            for (final l in ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'])
              VirtualKeyboardKey(
                text: char(l),
                onTap: () {
                  VirtualKeyboardBridge.insertText(char(l));
                  controller.onCharacterTyped();
                },
              ),
          ],
        ),
        // Row 3: ASDF + Enter
        Row(
          children: [
            for (final l in ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'])
              VirtualKeyboardKey(
                text: char(l),
                onTap: () {
                  VirtualKeyboardBridge.insertText(char(l));
                  controller.onCharacterTyped();
                },
              ),
            VirtualKeyboardKey(
              icon: Icons.keyboard_return_rounded,
              flex: 2,
              type: VirtualKeyType.primary,
              onTap: VirtualKeyboardBridge.submit,
            ),
          ],
        ),
        // Row 4: Shift + ZXCV + Shift
        Row(
          children: [
            VirtualKeyboardKey(
              icon: controller.isCapsLock
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_upward_outlined,
              flex: 2,
              type: controller.isCapsLock
                  ? VirtualKeyType.active
                  : (shifted ? VirtualKeyType.primary : VirtualKeyType.action),
              onTap: () {
                if (controller.isShifted && !controller.isCapsLock) {
                  controller.toggleCapsLock();
                } else if (controller.isCapsLock) {
                  controller.toggleCapsLock();
                } else {
                  controller.toggleShift();
                }
              },
            ),
            for (final l in ['z', 'x', 'c', 'v', 'b', 'n', 'm'])
              VirtualKeyboardKey(
                text: char(l),
                onTap: () {
                  VirtualKeyboardBridge.insertText(char(l));
                  controller.onCharacterTyped();
                },
              ),
            VirtualKeyboardKey(
              text: ',',
              onTap: () {
                VirtualKeyboardBridge.insertText(',');
                controller.onCharacterTyped();
              },
            ),
            VirtualKeyboardKey(
              text: '.',
              onTap: () {
                VirtualKeyboardBridge.insertText('.');
                controller.onCharacterTyped();
              },
            ),
            VirtualKeyboardKey(
              icon: controller.isCapsLock
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_upward_outlined,
              flex: 2,
              type: controller.isCapsLock
                  ? VirtualKeyType.active
                  : (shifted ? VirtualKeyType.primary : VirtualKeyType.action),
              onTap: () {
                if (controller.isShifted && !controller.isCapsLock) {
                  controller.toggleCapsLock();
                } else if (controller.isCapsLock) {
                  controller.toggleCapsLock();
                } else {
                  controller.toggleShift();
                }
              },
            ),
          ],
        ),
        // Row 5: Symbols, @, Space, _, -, Done
        Row(
          children: [
            VirtualKeyboardKey(
              text: '?123',
              flex: 2,
              type: VirtualKeyType.action,
              onTap: () => controller.setMode(VirtualKeyboardMode.symbols),
            ),
            VirtualKeyboardKey(
              text: '@',
              onTap: () {
                VirtualKeyboardBridge.insertText('@');
                controller.onCharacterTyped();
              },
            ),
            VirtualKeyboardKey(
              text: 'Space',
              flex: 5,
              onTap: VirtualKeyboardBridge.space,
            ),
            VirtualKeyboardKey(
              text: '_',
              onTap: () {
                VirtualKeyboardBridge.insertText('_');
                controller.onCharacterTyped();
              },
            ),
            VirtualKeyboardKey(
              text: '-',
              onTap: () {
                VirtualKeyboardBridge.insertText('-');
                controller.onCharacterTyped();
              },
            ),
            VirtualKeyboardKey(
              text: 'Done',
              flex: 2,
              type: VirtualKeyType.action,
              onTap: () => controller.hide(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSymbolsLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Numbers + Backspace
        Row(
          children: [
            for (final n in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
              VirtualKeyboardKey(
                text: n,
                onTap: () => VirtualKeyboardBridge.insertText(n),
              ),
            VirtualKeyboardKey(
              icon: Icons.backspace_outlined,
              flex: 2,
              type: VirtualKeyType.action,
              onTap: VirtualKeyboardBridge.backspace,
            ),
          ],
        ),
        // Row 2: Top symbols
        Row(
          children: [
            for (final s in ['~', '!', '@', '#', '\$', '%', '^', '&', '*', '(', ')'])
              VirtualKeyboardKey(
                text: s,
                onTap: () => VirtualKeyboardBridge.insertText(s),
              ),
          ],
        ),
        // Row 3: Mid symbols
        Row(
          children: [
            for (final s in ['-', '_', '=', '+', '[', ']', '{', '}', '\\', '|'])
              VirtualKeyboardKey(
                text: s,
                onTap: () => VirtualKeyboardBridge.insertText(s),
              ),
          ],
        ),
        // Row 4: Punctuation symbols + Enter
        Row(
          children: [
            for (final s in [';', ':', '\'', '"', '<', '>', ',', '.', '?', '/'])
              VirtualKeyboardKey(
                text: s,
                onTap: () => VirtualKeyboardBridge.insertText(s),
              ),
            VirtualKeyboardKey(
              icon: Icons.keyboard_return_rounded,
              flex: 2,
              type: VirtualKeyType.primary,
              onTap: VirtualKeyboardBridge.submit,
            ),
          ],
        ),
        // Row 5: ABC switch, Space, Done
        Row(
          children: [
            VirtualKeyboardKey(
              text: 'ABC',
              flex: 2,
              type: VirtualKeyType.action,
              onTap: () => controller.setMode(VirtualKeyboardMode.alphanumeric),
            ),
            VirtualKeyboardKey(
              text: 'Space',
              flex: 7,
              onTap: VirtualKeyboardBridge.space,
            ),
            VirtualKeyboardKey(
              text: 'Done',
              flex: 2,
              type: VirtualKeyType.action,
              onTap: () => controller.hide(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumericLayout() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              VirtualKeyboardKey(
                text: '1',
                onTap: () => VirtualKeyboardBridge.insertText('1'),
              ),
              VirtualKeyboardKey(
                text: '2',
                onTap: () => VirtualKeyboardBridge.insertText('2'),
              ),
              VirtualKeyboardKey(
                text: '3',
                onTap: () => VirtualKeyboardBridge.insertText('3'),
              ),
              VirtualKeyboardKey(
                icon: Icons.backspace_outlined,
                type: VirtualKeyType.action,
                onTap: VirtualKeyboardBridge.backspace,
              ),
            ],
          ),
          Row(
            children: [
              VirtualKeyboardKey(
                text: '4',
                onTap: () => VirtualKeyboardBridge.insertText('4'),
              ),
              VirtualKeyboardKey(
                text: '5',
                onTap: () => VirtualKeyboardBridge.insertText('5'),
              ),
              VirtualKeyboardKey(
                text: '6',
                onTap: () => VirtualKeyboardBridge.insertText('6'),
              ),
              VirtualKeyboardKey(
                text: 'Clear',
                type: VirtualKeyType.action,
                onTap: VirtualKeyboardBridge.clear,
              ),
            ],
          ),
          Row(
            children: [
              VirtualKeyboardKey(
                text: '7',
                onTap: () => VirtualKeyboardBridge.insertText('7'),
              ),
              VirtualKeyboardKey(
                text: '8',
                onTap: () => VirtualKeyboardBridge.insertText('8'),
              ),
              VirtualKeyboardKey(
                text: '9',
                onTap: () => VirtualKeyboardBridge.insertText('9'),
              ),
              VirtualKeyboardKey(
                text: 'ABC',
                type: VirtualKeyType.action,
                onTap: () => controller.setMode(VirtualKeyboardMode.alphanumeric),
              ),
            ],
          ),
          Row(
            children: [
              VirtualKeyboardKey(
                text: '-',
                onTap: () => VirtualKeyboardBridge.insertText('-'),
              ),
              VirtualKeyboardKey(
                text: '0',
                onTap: () => VirtualKeyboardBridge.insertText('0'),
              ),
              VirtualKeyboardKey(
                text: '.',
                onTap: () => VirtualKeyboardBridge.insertText('.'),
              ),
              VirtualKeyboardKey(
                text: 'Done',
                type: VirtualKeyType.primary,
                onTap: () => controller.hide(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

