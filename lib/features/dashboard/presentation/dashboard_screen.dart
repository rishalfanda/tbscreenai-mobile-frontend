import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock_data.dart';
import 'package:myapp/state/dashboard_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, dashboard),
              const SizedBox(height: 24),
              if (dashboard.isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _buildStatCards(context),
                const SizedBox(height: 16),
                _buildAgreementLevelRow(context),
                const SizedBox(height: 24),
                _buildDiagnosisTrendsChart(context),
                const SizedBox(height: 24),
                _buildDistributionDonuts(context),
                const SizedBox(height: 24),
                _buildRecentActivity(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, DashboardProvider dashboard) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1200;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back, Dr. Anderson',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.subtitleGrey),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildDropdown(
              value: dashboard.selectedTimePeriod,
              items: dashboard.timePeriods,
              onChanged: (v) => dashboard.setTimePeriod(v!),
              width: isCompact ? 160 : 180,
            ),
            _buildDropdown(
              value: dashboard.selectedInstitution,
              items: dashboard.institutions,
              onChanged: (v) => dashboard.setInstitution(v!),
              width: isCompact ? 200 : 220,
            ),
            FilledButton.icon(
              onPressed: () => context.go('/diagnosis'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Diagnosis'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.subtitleGrey),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatCards(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 1100 ? 2 : 4;
    final aspectRatio = screenWidth < 1100 ? 1.5 : 1.3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: MockData.dashboardMetrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) {
        final metric = MockData.dashboardMetrics[index];
        final isPositive = metric.change.startsWith('+');
        
        final iconData = switch (metric.icon) {
          'people' => Icons.people_alt_rounded,
          'analytics' => Icons.analytics_rounded,
          'verified' => Icons.verified_user_rounded,
          'pending' => Icons.pending_actions_rounded,
          _ => Icons.bar_chart_rounded,
        };

        final Color iconColor = metric.iconColor ?? (switch (metric.icon) {
          'people' => AppTheme.lightBlue,
          'analytics' => AppTheme.purple,
          _ => AppTheme.primary,
        });

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            side: const BorderSide(color: AppTheme.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData, color: iconColor),
                ),
                const Spacer(),
                Text(
                  metric.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.subtitleGrey),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.value,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navy,
                                  fontSize: 22,
                                ),
                          ),
                          if (metric.subtext != null)
                            Text(
                              metric.subtext!,
                              style: const TextStyle(color: AppTheme.subtitleGrey, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isPositive ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        metric.change,
                        style: TextStyle(
                          color: isPositive ? AppTheme.success : AppTheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgreementLevelRow(BuildContext context) {
    const double agreementPct = 88.8;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agreement Level',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy, fontSize: 18),
                    ),
                    Text(
                      'Consistency between AI diagnosis and doctor diagnosis',
                      style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  '$agreementPct%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: agreementPct.toInt(),
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
                    ),
                  ),
                ),
                Expanded(
                  flex: (100 - agreementPct).toInt(),
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, color: AppTheme.success, size: 10),
                    SizedBox(width: 4),
                    Text('Agreed', style: TextStyle(fontSize: 12, color: AppTheme.subtitleGrey)),
                    SizedBox(width: 16),
                    Icon(Icons.circle, color: AppTheme.error, size: 10),
                    SizedBox(width: 4),
                    Text('Disagreed', style: TextStyle(fontSize: 12, color: AppTheme.subtitleGrey)),
                  ],
                ),
                Text(
                  'of 3,139 validated cases',
                  style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisTrendsChart(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Diagnosis Trends Over Time',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy, fontSize: 18),
                ),
                Row(
                  children: [
                    _buildLegendItem('Total Diagnoses', AppTheme.primary),
                    const SizedBox(width: 16),
                    _buildLegendItem('Total Patients', AppTheme.lightBlue),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              height: 240,
              width: double.infinity,
              color: Colors.transparent,
              child: CustomPaint(
                painter: TrendsChartPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.subtitleGrey)),
      ],
    );
  }

  Widget _buildDistributionDonuts(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildDonut('TB Case Distribution by AI', 65, '428 cases')),
                const SizedBox(width: 24),
                Expanded(child: _buildDonut('TB Case Distribution by Doctor', 58, '247 validated')),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Doctor distribution only includes validated cases.',
              style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonut(String title, int positivePct, String totalLabel) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy, fontSize: 16)),
        const SizedBox(height: 24),
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: positivePct / 100,
                  strokeWidth: 20,
                  backgroundColor: AppTheme.success.withValues(alpha: 0.2),
                  color: AppTheme.error,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$positivePct%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppTheme.navy)),
                  const Text('Positive', style: TextStyle(fontSize: 12, color: AppTheme.subtitleGrey)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(totalLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.navy)),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy, fontSize: 18),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...MockData.recentActivities.map(
              (activity) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      foregroundColor: AppTheme.primaryDark,
                      child: Text(
                        activity.name.split(' ').where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(activity.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy)),
                          const SizedBox(height: 2),
                          Text(
                            '${activity.timestamp} · ${activity.institution}',
                            style: const TextStyle(color: AppTheme.subtitleGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: activity.result == 'Positive' ? AppTheme.red.withValues(alpha: 0.1) : AppTheme.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            activity.result,
                            style: TextStyle(
                              color: activity.result == 'Positive' ? AppTheme.red : AppTheme.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activity.confidence}% confidence',
                          style: const TextStyle(color: AppTheme.subtitleGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrendsChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final paint2 = Paint()
      ..color = AppTheme.lightBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path1 = Path();
    final path2 = Path();

    // Mock trend paths
    path1.moveTo(0, size.height * 0.7);
    path1.quadraticBezierTo(size.width * 0.2, size.height * 0.4, size.width * 0.4, size.height * 0.6);
    path1.quadraticBezierTo(size.width * 0.6, size.height * 0.8, size.width * 0.8, size.height * 0.3);
    path1.lineTo(size.width, size.height * 0.5);

    path2.moveTo(0, size.height * 0.8);
    path2.quadraticBezierTo(size.width * 0.2, size.height * 0.5, size.width * 0.4, size.height * 0.7);
    path2.quadraticBezierTo(size.width * 0.6, size.height * 0.9, size.width * 0.8, size.height * 0.4);
    path2.lineTo(size.width, size.height * 0.6);

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);

    // Draw axes
    final axisPaint = Paint()
      ..color = AppTheme.borderLight
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
