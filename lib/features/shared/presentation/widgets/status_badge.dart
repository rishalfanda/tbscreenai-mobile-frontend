import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// Pill badge that pairs color with an optional icon, so status is never
/// conveyed by color alone (accessibility: color-not-only).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  /// Maps a clinical status string to its semantic color + icon.
  factory StatusBadge.forStatus(String status, {bool dense = false}) {
    final normalized = status.toLowerCase();
    late Color color;
    late IconData icon;
    switch (normalized) {
      case 'positive':
      case 'disagreed':
        color = AppTheme.error;
        icon = Icons.warning_amber_rounded;
        break;
      case 'normal':
      case 'negative':
      case 'agreed':
      case 'active':
        color = AppTheme.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'pending':
        color = AppTheme.warning;
        icon = Icons.schedule_rounded;
        break;
      default:
        color = AppTheme.subtitleGrey;
        icon = Icons.circle;
    }
    return StatusBadge(label: status, color: color, icon: icon, dense: dense);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            SizedBox(width: dense ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
