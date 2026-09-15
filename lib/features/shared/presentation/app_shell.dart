import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';

/// Persistent navigation shell shared by all primary screens (ShellRoute).
/// Collapsible tablet rail and modal navigation on compact Android windows.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _items = <({String route, IconData icon, String label})>[
    (
      route: '/dashboard',
      icon: Icons.space_dashboard_rounded,
      label: 'Dashboard',
    ),
    (route: '/patients', icon: Icons.people_alt_rounded, label: 'Patients'),
    (route: '/diagnosis', icon: Icons.biotech_rounded, label: 'Screening'),
    (route: '/result', icon: Icons.analytics_rounded, label: 'Result'),
    (
      route: '/validation',
      icon: Icons.verified_user_rounded,
      label: 'Validation',
    ),
    (route: '/dataset', icon: Icons.table_chart_rounded, label: 'Dataset'),
    (route: '/sync', icon: Icons.cloud_sync_rounded, label: 'Sync'),
    (route: '/account', icon: Icons.person_rounded, label: 'Account'),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _pendingCount = 0;
  bool _railVisible = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
    final selectedIndex = AppShell._items.indexWhere(
      (item) => widget.location.startsWith(item.route),
    );

    final compact = MediaQuery.sizeOf(context).width < 840;
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    void navigate(String route) {
      _scaffoldKey.currentState?.closeDrawer();
      context.go(route);
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: compact
          ? Drawer(
              width: AppTheme.railWidth,
              shape: const RoundedRectangleBorder(),
              child: SafeArea(
                child: _NavRail(
                  items: AppShell._items,
                  selectedIndex: index,
                  pendingCount: _pendingCount,
                  onNavigate: navigate,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: !compact && _railVisible ? AppTheme.railWidth : 0,
              child: !compact && _railVisible
                  ? _NavRail(
                      items: AppShell._items,
                      selectedIndex: index,
                      pendingCount: _pendingCount,
                      onNavigate: navigate,
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Material(
                    color: AppTheme.background,
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          IconButton(
                            key: const ValueKey('navigation-toggle'),
                            constraints: const BoxConstraints.tightFor(
                              width: 48,
                              height: 48,
                            ),
                            tooltip: !compact && _railVisible
                                ? 'Hide navigation'
                                : 'Show navigation',
                            icon: Icon(
                              !compact && _railVisible
                                  ? Icons.menu_open
                                  : Icons.menu,
                            ),
                            color: AppTheme.navy,
                            onPressed: () {
                              if (compact) {
                                _scaffoldKey.currentState?.openDrawer();
                              } else {
                                setState(() => _railVisible = !_railVisible);
                              }
                            },
                          ),
                          Expanded(
                            child: Text(
                              AppShell._items[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppTheme.background,
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
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
    required this.onNavigate,
  });

  final List<({String route, IconData icon, String label})> items;
  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<String> onNavigate;

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
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/images/favicon.png',
                fit: BoxFit.contain,
                semanticLabel: 'TBScreen.AI',
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
                  onTap: () => onNavigate(item.route),
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
        : (_hovered
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.transparent);
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
                  boxShadow: widget.active
                      ? AppTheme.primaryGlow(alpha: 0.35)
                      : null,
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
                            fontWeight: widget.active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (widget.badgeCount != null && widget.badgeCount! > 0)
                      Positioned(
                        top: 4,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.navy,
                              width: 1.5,
                            ),
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
