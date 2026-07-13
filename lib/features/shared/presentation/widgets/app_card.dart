import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// Standard surface used across screens. Optionally lifts on hover/press when
/// [onTap] is provided, giving tablet + web-preview affordance without shifting
/// layout bounds.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.sp24),
    this.onTap,
    this.selected = false,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;

  /// When set, a colored left indicator + tinted border marks the card.
  final Color? accent;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (mounted) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final borderColor = widget.selected
        ? AppTheme.primary
        : (widget.accent != null
            ? widget.accent!.withValues(alpha: 0.35)
            : AppTheme.borderLight);
    final elevate = interactive && (_hovered || widget.selected);

    final card = AnimatedContainer(
      duration: AppTheme.motionBase,
      curve: AppTheme.motionCurve,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: borderColor,
          width: widget.selected ? 2 : 1,
        ),
        boxShadow: elevate ? AppTheme.shadowMd : AppTheme.shadowSm,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (!interactive) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }
}
