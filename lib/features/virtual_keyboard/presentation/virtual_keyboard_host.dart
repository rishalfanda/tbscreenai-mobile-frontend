import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/virtual_keyboard/application/virtual_keyboard_bridge.dart';
import 'package:myapp/features/virtual_keyboard/application/virtual_keyboard_controller.dart';
import 'package:myapp/features/virtual_keyboard/presentation/virtual_keyboard_view.dart';

/// Hosts the virtual keyboard globally around the app's root Navigator.
///
/// On Linux and desktop platforms (where no native soft keyboard is provided by
/// the OS or cage kiosk compositor), this automatically brings up an on-screen
/// keyboard when any [TextField] or [TextFormField] gains focus, and docks it at
/// the bottom of the viewport so content is never obscured.
class VirtualKeyboardHost extends StatefulWidget {
  const VirtualKeyboardHost({
    super.key,
    required this.child,
    this.controller,
    this.enableOnAllPlatforms = false,
  });

  final Widget child;
  final VirtualKeyboardController? controller;

  /// If true, enables the in-app virtual keyboard regardless of platform
  /// (primarily for testing and explicit kiosk configurations).
  final bool enableOnAllPlatforms;

  @override
  State<VirtualKeyboardHost> createState() => _VirtualKeyboardHostState();
}

class _VirtualKeyboardHostState extends State<VirtualKeyboardHost> {
  late final VirtualKeyboardController _controller;
  late final bool _isOwnedController;

  bool get _isSupportedPlatform =>
      widget.enableOnAllPlatforms ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS));

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isOwnedController = false;
    } else {
      _controller = VirtualKeyboardController();
      _isOwnedController = true;
    }
  }

  @override
  void dispose() {
    if (_isOwnedController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isVisible = _controller.isVisible;
        final hasActiveInput =
            VirtualKeyboardBridge.currentEditableTextState != null;

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) {
                      // If keyboard is open and user taps on the content area above,
                      // check on next microtask if focus moved outside editable inputs
                      if (_controller.isVisible) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final primary = FocusManager.instance.primaryFocus;
                          final isEditable = primary?.context?.findAncestorStateOfType<EditableTextState>() != null;
                          if (!isEditable) {
                            _controller.hide(unfocus: true);
                          }
                        });
                      }
                    },
                    child: widget.child,
                  ),
                ),
                if (isVisible)
                  VirtualKeyboardView(controller: _controller),
              ],
            ),
            // Floating summon button when an input is focused but keyboard is closed
            if (!isVisible && hasActiveInput)
              Positioned(
                right: 20,
                bottom: 20,
                child: Material(
                  color: AppTheme.primary,
                  shape: const CircleBorder(),
                  elevation: 6,
                  child: InkWell(
                    canRequestFocus: false,
                    customBorder: const CircleBorder(),
                    onTap: _controller.show,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(
                        Icons.keyboard_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
