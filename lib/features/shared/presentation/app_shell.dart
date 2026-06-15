import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/validation_mock.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _items = <({String route, IconData icon, String label})>[
    (route: '/dashboard', icon: Icons.space_dashboard_rounded, label: 'Dashboard'),
    (route: '/patients', icon: Icons.people_alt_rounded, label: 'Patients'),
    (route: '/diagnosis', icon: Icons.biotech_rounded, label: 'Diagnose'),
    (route: '/validation', icon: Icons.verified_user_rounded, label: 'Validation'),
    (route: '/dataset', icon: Icons.table_chart_rounded, label: 'Dataset'),
    (route: '/account', icon: Icons.person_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _items.indexWhere((item) => location.startsWith(item.route));
    final pendingCount = mockCases.where((c) => c.status == "pending").length;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: AppTheme.railWidth,
              color: AppTheme.navy,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 20),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'TB',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _NavItem(
                          icon: item.icon,
                          label: item.label,
                          active: (selectedIndex < 0 ? 0 : selectedIndex) == index,
                          badgeCount: item.route == '/validation' ? pendingCount : null,
                          onTap: () => context.go(item.route),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox.expand(
                child: Container(
                  color: AppTheme.background,
                  child: child,
                ),
              ),
            ),
          ],
        ),
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

  // Fix: check mounted before setState to prevent mouse_tracker assertion
  void _setHovered(bool value) {
    if (mounted) setState(() => _hovered = value);
  }

  @override
  void dispose() {
    _hovered = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? AppTheme.primary
        : (_hovered ? const Color(0xFF2D4A6A) : Colors.transparent);
    final iconColor = widget.active ? Colors.white : AppTheme.inactiveRail;
    final labelColor = widget.active ? Colors.white : AppTheme.inactiveRail;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: SizedBox(
              width: 56,
              height: 64,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(child: Icon(widget.icon, size: 20, color: iconColor)),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              color: labelColor,
                              fontWeight: widget.active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.badgeCount != null && widget.badgeCount! > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
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