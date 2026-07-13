import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';

/// Page-level title with optional subtitle and trailing action area.
/// Wraps gracefully on narrower tablet widths.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.subtitleGrey),
          ),
        ],
      ],
    );

    if (trailing == null) return text;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: AppTheme.sp16,
      spacing: AppTheme.sp16,
      children: [
        text,
        trailing!,
      ],
    );
  }
}
