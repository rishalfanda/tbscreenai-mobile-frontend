import 'package:flutter/material.dart';

/// Bridges the on-screen virtual keyboard with the currently active
/// [EditableTextState] in the Flutter widget tree.
///
/// By updating [EditableTextState] directly via [userUpdateTextEditingValue],
/// all existing [TextField], [TextFormField], and custom text inputs across the
/// application receive text updates naturally, triggering input formatters,
/// validation, caret position tracking, and `onChanged` listeners without
/// requiring any proprietary replacement widgets.
class VirtualKeyboardBridge {
  const VirtualKeyboardBridge();

  static EditableTextState? _activeEditableTextState;
  static FocusNode? _activeFocusNode;

  /// Resolves the active [EditableTextState], preferring the current primary focus
  /// if it is an input, or falling back to the actively tracked input during keyboard usage.
  static EditableTextState? get currentEditableTextState {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.context != null) {
      final state = focus.context!.findAncestorStateOfType<EditableTextState>();
      if (state != null) {
        _activeEditableTextState = state;
        _activeFocusNode = focus;
        return state;
      }
    }
    if (_activeEditableTextState != null && _activeEditableTextState!.mounted) {
      return _activeEditableTextState;
    }
    return null;
  }

  /// Explicitly registers an active [EditableTextState] and its [FocusNode].
  static void registerActiveState(EditableTextState state, FocusNode focusNode) {
    _activeEditableTextState = state;
    _activeFocusNode = focusNode;
  }

  /// Restores focus to the active text input if not already focused.
  static void ensureFocus() {
    if (_activeFocusNode != null &&
        _activeFocusNode!.canRequestFocus &&
        !_activeFocusNode!.hasFocus) {
      _activeFocusNode!.requestFocus();
    }
  }

  /// Clears tracked state on explicit keyboard dismiss or submit.
  static void clearActiveState() {
    _activeEditableTextState = null;
    _activeFocusNode = null;
  }

  /// Inserts [textToInsert] at the current cursor position, replacing any
  /// active text selection.
  static void insertText(String textToInsert) {
    final state = currentEditableTextState;
    if (state == null) return;
    ensureFocus();

    final value = state.textEditingValue;
    final selection = value.selection;
    final text = value.text;

    String newText;
    int newSelectionIndex;

    if (selection.isValid && !selection.isCollapsed) {
      final start = selection.start;
      final end = selection.end;
      newText = text.replaceRange(start, end, textToInsert);
      newSelectionIndex = start + textToInsert.length;
    } else {
      final cursor = selection.isValid ? selection.baseOffset : text.length;
      final clampedCursor = cursor.clamp(0, text.length);
      newText = text.replaceRange(clampedCursor, clampedCursor, textToInsert);
      newSelectionIndex = clampedCursor + textToInsert.length;
    }

    final newValue = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
      composing: TextRange.empty,
    );
    state.userUpdateTextEditingValue(newValue, SelectionChangedCause.keyboard);
  }

  /// Deletes the character preceding the cursor, or the entire selected range
  /// if a text selection is active.
  static void backspace() {
    final state = currentEditableTextState;
    if (state == null) return;
    ensureFocus();

    final value = state.textEditingValue;
    final selection = value.selection;
    final text = value.text;

    if (selection.isValid && !selection.isCollapsed) {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, '');
      final newValue = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      state.userUpdateTextEditingValue(newValue, SelectionChangedCause.keyboard);
    } else if (text.isNotEmpty) {
      final cursor = selection.isValid ? selection.baseOffset : text.length;
      if (cursor > 0) {
        final deleteFrom = cursor - 1;
        final newText = text.replaceRange(deleteFrom, cursor, '');
        final newValue = value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: deleteFrom),
          composing: TextRange.empty,
        );
        state.userUpdateTextEditingValue(newValue, SelectionChangedCause.keyboard);
      }
    }
  }

  /// Inserts a space character.
  static void space() => insertText(' ');

  /// Clears the entire contents of the focused text field.
  static void clear() {
    final state = currentEditableTextState;
    if (state == null) return;
    ensureFocus();

    final newValue = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );
    state.userUpdateTextEditingValue(newValue, SelectionChangedCause.keyboard);
  }

  /// Submits the current field or performs its [TextInputAction].
  static void submit() {
    final state = currentEditableTextState;
    if (state == null) return;

    final widget = state.widget;
    final text = state.textEditingValue.text;

    if (widget.maxLines == 1) {
      widget.onSubmitted?.call(text);
      final action = widget.textInputAction ?? TextInputAction.done;
      if (action == TextInputAction.next) {
        FocusManager.instance.primaryFocus?.nextFocus();
      } else if (action == TextInputAction.done ||
          action == TextInputAction.go ||
          action == TextInputAction.search) {
        FocusManager.instance.primaryFocus?.unfocus();
        clearActiveState();
      }
    } else {
      insertText('\n');
    }
  }
}
