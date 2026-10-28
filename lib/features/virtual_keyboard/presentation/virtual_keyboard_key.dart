import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';

enum VirtualKeyType {
  standard,
  action,
  primary,
  active,
}

/// A touch-friendly individual key on the virtual keyboard.
///
/// Designed with [canRequestFocus: false] so tapping keys never interrupts or
/// steals focus from the active [EditableTextState].
class VirtualKeyboardKey extends StatelessWidget {
  const VirtualKeyboardKey({
    super.key,
    this.text,
    this.icon,
    required this.onTap,
    this.flex = 1,
    this.type = VirtualKeyType.standard,
  }) : assert(text != null || icon != null, 'Key must have text or icon');

  final String? text;
  final IconData? icon;
  final VoidCallback? onTap;
  final int flex;
  final VirtualKeyType type;

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor) = switch (type) {
      VirtualKeyType.primary => (AppTheme.primary, Colors.white),
      VirtualKeyType.active => (AppTheme.primary.withValues(alpha: 0.85), Colors.white),
      VirtualKeyType.action => (const Color(0xFF334155), Colors.white),
      VirtualKeyType.standard => (const Color(0xFF1E293B), Colors.white),
    };

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3.0),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          elevation: 1.5,
          shadowColor: Colors.black45,
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(8),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            onTap: onTap,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, color: fgColor, size: 20)
                  : Text(
                      text!,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: (text!.length > 1) ? 13 : 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

