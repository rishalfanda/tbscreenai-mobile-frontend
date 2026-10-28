import 'package:flutter/material.dart';
import 'package:myapp/features/virtual_keyboard/application/virtual_keyboard_bridge.dart';

enum VirtualKeyboardMode {
  alphanumeric,
  numeric,
  symbols,
}

/// Manages the visibility, layout mode, and shift states of the in-app
/// virtual keyboard.
class VirtualKeyboardController extends ChangeNotifier {
  VirtualKeyboardController({
    bool autoShow = true,
  }) : _autoShow = autoShow {
    FocusManager.instance.addListener(_handleFocusChange);
  }

  bool _isVisible = false;
  bool _autoShow = true;
  VirtualKeyboardMode _mode = VirtualKeyboardMode.alphanumeric;
  bool _isShifted = false;
  bool _isCapsLock = false;

  bool get isVisible => _isVisible;
  bool get autoShow => _autoShow;
  VirtualKeyboardMode get mode => _mode;
  bool get isShifted => _isShifted || _isCapsLock;
  bool get isCapsLock => _isCapsLock;

  void _handleFocusChange() {
    final state = VirtualKeyboardBridge.currentEditableTextState;
    if (state != null) {
      final inputType = state.widget.keyboardType;
      if (inputType == TextInputType.number ||
          inputType == TextInputType.phone ||
          inputType == const TextInputType.numberWithOptions(decimal: true) ||
          inputType == const TextInputType.numberWithOptions(signed: true)) {
        _mode = VirtualKeyboardMode.numeric;
      } else if (_mode == VirtualKeyboardMode.numeric) {
        _mode = VirtualKeyboardMode.alphanumeric;
      }

      if (_autoShow && !_isVisible) {
        _isVisible = true;
      }
      notifyListeners();
    } else {
      if (_isVisible) {
        _isVisible = false;
        notifyListeners();
      }
    }
  }

  /// Manually shows the virtual keyboard.
  void show() {
    if (!_isVisible) {
      _isVisible = true;
      notifyListeners();
    }
  }

  /// Dismisses the virtual keyboard.
  /// If [unfocus] is true, also releases focus from the active text field.
  void hide({bool unfocus = false}) {
    if (unfocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (_isVisible) {
      _isVisible = false;
      notifyListeners();
    }
  }

  /// Toggles visibility of the virtual keyboard.
  void toggle() {
    if (_isVisible) {
      hide();
    } else {
      show();
    }
  }

  /// Sets the active keyboard layout mode.
  void setMode(VirtualKeyboardMode mode) {
    if (_mode != mode) {
      _mode = mode;
      _isShifted = false;
      notifyListeners();
    }
  }

  /// Toggles shift (single character uppercase).
  void toggleShift() {
    _isShifted = !_isShifted;
    notifyListeners();
  }

  /// Toggles caps lock (persistent uppercase).
  void toggleCapsLock() {
    _isCapsLock = !_isCapsLock;
    _isShifted = _isCapsLock;
    notifyListeners();
  }

  /// Called after a character key is pressed to consume temporary shift state.
  void onCharacterTyped() {
    if (_isShifted && !_isCapsLock) {
      _isShifted = false;
      notifyListeners();
    }
  }

  /// Updates whether the keyboard should automatically pop up on focus.
  void setAutoShow(bool value) {
    if (_autoShow != value) {
      _autoShow = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }
}

