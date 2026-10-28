import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/shared/presentation/widgets/app_card.dart';

class InstitutionGrid extends StatelessWidget {
  const InstitutionGrid({
    super.key,
    required this.children,
    this.maxColumns = 4,
    this.equalHeight = true,
  });
  final List<Widget> children;
  final int maxColumns;
  final bool equalHeight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final columns = (size.maxWidth / 260).floor().clamp(1, maxColumns);
      if (!equalHeight) {
        final width = (size.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      }
      return Column(
        children: [
          for (var offset = 0; offset < children.length; offset += columns) ...[
            if (offset > 0) const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 16),
                    Expanded(
                      child: offset + column < children.length
                          ? children[offset + column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class InstitutionIcon extends StatelessWidget {
  const InstitutionIcon(
    this.icon, {
    super.key,
    this.color = AppTheme.primaryDark,
  });
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class InstitutionMetric extends StatelessWidget {
  const InstitutionMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.color = AppTheme.primaryDark,
  });
  final IconData icon;
  final String label, value, caption;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha: 0.045),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      side: BorderSide(color: color.withValues(alpha: 0.16)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InstitutionIcon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(caption, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class InstitutionTask extends StatelessWidget {
  const InstitutionTask({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.route,
  });
  final IconData icon;
  final String title, description, action, route;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InstitutionIcon(icon),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.subtitleGrey),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => context.go(route),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(action),
        ),
      ],
    ),
  );
}

class InstitutionPanel extends StatelessWidget {
  const InstitutionPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}
