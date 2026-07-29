import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';

/// Persistent navigation shell shared by all primary screens (ShellRoute).
/// A fixed left NavRail keeps top-level destinations reachable at all times —
/// the adaptive pattern for tablet / large screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _items = <({String route, IconData icon, String label})>[
    (route: '/dashboard', icon: Icons.space_dashboard_rounded, label: 'Dashboard'),
    (route: '/patients', icon: Icons.people_alt_rounded, label: 'Patients'),
    (route: '/diagnosis', icon: Icons.biotech_rounded, label: 'Diagnose'),
    (route: '/result', icon: Icons.analytics_rounded, label: 'Result'),
    (route: '/validation', icon: Icons.verified_user_rounded, label: 'Validation'),
    (route: '/dataset', icon: Icons.table_chart_rounded, label: 'Dataset'),
    (route: '/sync', icon: Icons.cloud_sync_rounded, label: 'Sync'),
    (route: '/account', icon: Icons.person_rounded, label: 'Account'),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    // Mock repository resolves synchronously, so the badge is correct on the
    // very first frame — same as reading the static list pre-refactor.
    context.read<ValidationRepository>().getCases().then((cases) {
      final count = cases.where((c) => c.status == 'pending').length;
      if (!mounted) return;
      setState(() => _pendingCount = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        AppShell._items.indexWhere((item) => widget.location.startsWith(item.route));

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _NavRail(
              items: AppShell._items,
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              pendingCount: _pendingCount,
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: AppTheme.background),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.items,
    required this.selectedIndex,
    required this.pendingCount,
  });

  final List<({String route, IconData icon, String label})> items;
  final int selectedIndex;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppTheme.railWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.navy, AppTheme.navyDark],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 22),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: AppTheme.primaryGlow(alpha: 0.4),
              ),
              alignment: Alignment.center,
              child: const Text(
                'TB',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _NavItem(
                  icon: item.icon,
                  label: item.label,
                  active: selectedIndex == index,
                  badgeCount: item.route == '/validation' ? pendingCount : null,
                  onTap: () => context.go(item.route),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  // Guard against setState after unmount (avoids mouse_tracker assertion on web).
  void _setHovered(bool value) {
    if (mounted) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? AppTheme.primary
        : (_hovered ? Colors.white.withValues(alpha: 0.10) : Colors.transparent);
    final fg = widget.active ? Colors.white : AppTheme.inactiveRail;

    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Tooltip(
          message: widget.label,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _setHovered(false),
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppTheme.motionBase,
                curve: AppTheme.motionCurve,
                height: 60,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: widget.active ? AppTheme.primaryGlow(alpha: 0.35) : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 22, color: fg),
                        const SizedBox(height: 4),
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: fg,
                            fontWeight:
                                widget.active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (widget.badgeCount != null && widget.badgeCount! > 0)
                      Positioned(
                        top: 4,
                        right: 8,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.navy, width: 1.5),
                          ),
                          child: Text(
                            '${widget.badgeCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
