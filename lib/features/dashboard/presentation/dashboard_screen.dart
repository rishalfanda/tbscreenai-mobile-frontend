import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/models.dart';
import 'package:myapp/state/dashboard_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final pagePadding = constraints.maxWidth < 700 ? 16.0 : 24.0;
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.all(pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, dashboard),
                  const SizedBox(height: 20),
                  if (dashboard.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _buildStatCards(context, dashboard),
                    const SizedBox(height: 16),
                    _buildAgreementLevelRow(context),
                    const SizedBox(height: 16),
                    _buildDiagnosisTrendsChart(context, dashboard),
                    const SizedBox(height: 16),
                    _buildDistributionDonuts(context, dashboard),
                    const SizedBox(height: 16),
                    _buildRecentActivity(context, dashboard),
                  ],
                ],
              ),
            );
          },
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
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.subtitleGrey),
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
              label: const Text('New Screening'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.subtitleGrey,
          ),
          items: items
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, DashboardProvider dashboard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = switch (constraints.maxWidth) {
          < 560 => 1,
          < 1080 => 2,
          _ => 4,
        };

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dashboard.metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: crossAxisCount == 1 ? 112 : 128,
          ),
          itemBuilder: (context, index) {
            final metric = dashboard.metrics[index];
            final isPositive = metric.change.startsWith('+');

            final iconData = switch (metric.icon) {
              'people' => Icons.people_alt_rounded,
              'analytics' => Icons.monitor_heart_rounded,
              'verified' => Icons.verified_user_rounded,
              'pending' => Icons.pending_actions_rounded,
              _ => Icons.bar_chart_rounded,
            };

            // Map the semantic tone to theme colors; fall back to the per-icon
            // accent (same visual result as the old Color-carrying model).
            final Color iconColor = switch (metric.tone) {
              MetricTone.success => AppTheme.success,
              MetricTone.warning => AppTheme.warning,
              null => switch (metric.icon) {
                'people' => AppTheme.lightBlue,
                'analytics' => AppTheme.primaryDark,
                _ => AppTheme.primary,
              },
            };

            return Card(
              color: iconColor.withValues(alpha: 0.045),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                side: BorderSide(color: iconColor.withValues(alpha: 0.16)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconData, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.subtitleGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  metric.value,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.navy,
                                        fontSize: 22,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isPositive
                                              ? AppTheme.success
                                              : AppTheme.error)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  metric.change,
                                  style: TextStyle(
                                    color: isPositive
                                        ? AppTheme.successDark
                                        : AppTheme.errorDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (metric.subtext != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              metric.subtext!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.subtitleGrey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAgreementLevelRow(BuildContext context) {
    const double agreementPct = 88.8;
    return Card(
      color: AppTheme.success.withValues(alpha: 0.035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: AppTheme.success.withValues(alpha: 0.16)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 680;
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: isCompact
                          ? double.infinity
                          : constraints.maxWidth - 140,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agreement Level',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navy,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Consistency between AI screening and doctor review',
                            style: TextStyle(
                              color: AppTheme.subtitleGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$agreementPct%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: agreementPct / 100,
                    minHeight: 10,
                    backgroundColor: AppTheme.error.withValues(alpha: 0.18),
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    _StatusKey(color: AppTheme.success, label: 'Agreed 88.8%'),
                    _StatusKey(color: AppTheme.error, label: 'Disagreed 11.2%'),
                    Text(
                      '3,139 validated cases',
                      style: TextStyle(
                        color: AppTheme.subtitleGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiagnosisTrendsChart(
    BuildContext context,
    DashboardProvider dashboard,
  ) {
    return Card(
      color: AppTheme.primary.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                const Text(
                  'Screening volume, last 30 days',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                    fontSize: 17,
                  ),
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _buildLegendItem('Total Screenings', AppTheme.primaryDark),
                    _buildLegendItem(
                      'Total Patients',
                      AppTheme.navy,
                      dashed: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: constraints.maxWidth < 600 ? 190 : 220,
                width: double.infinity,
                child: CustomPaint(
                  painter: TrendsChartPainter(dashboard.trendData),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dashed
                ? List.generate(
                    3,
                    (_) => Container(width: 5, height: 3, color: color),
                  )
                : [Expanded(child: Container(height: 3, color: color))],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.subtitleGrey),
        ),
      ],
    );
  }

  Widget _buildDistributionDonuts(
    BuildContext context,
    DashboardProvider dashboard,
  ) {
    return Card(
      color: AppTheme.navy.withValues(alpha: 0.025),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                const Text(
                  'TB Case Distribution',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                    fontSize: 17,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dashboard.selectedDistributionFilter,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.subtitleGrey,
                      ),
                      items: dashboard.distributionFilters
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => dashboard.setDistributionFilter(v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackPanels = constraints.maxWidth < 700;
                final panels = [
                  _buildDonut('AI screening', 65, '428 cases'),
                  _buildDonut('Doctor review', 58, '247 validated'),
                ];
                if (stackPanels) {
                  return Column(
                    children: [
                      panels.first,
                      const SizedBox(height: 12),
                      panels.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: panels.first),
                    const SizedBox(width: 12),
                    Expanded(child: panels.last),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Doctor distribution only includes validated cases.',
              style: TextStyle(
                color: AppTheme.subtitleGrey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonut(String title, int positivePct, String totalLabel) {
    final negativePct = 100 - positivePct;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chart = SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 94,
                  height: 94,
                  child: CircularProgressIndicator(
                    value: positivePct / 100,
                    strokeWidth: 12,
                    backgroundColor: AppTheme.success.withValues(alpha: 0.22),
                    color: AppTheme.error,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$positivePct%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppTheme.navy,
                      ),
                    ),
                    const Text(
                      'Positive',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.subtitleGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalLabel,
                style: const TextStyle(
                  color: AppTheme.subtitleGrey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              _StatusKey(
                color: AppTheme.error,
                label: 'Positive $positivePct%',
              ),
              const SizedBox(height: 6),
              _StatusKey(
                color: AppTheme.success,
                label: 'Negative $negativePct%',
              ),
            ],
          );

          if (constraints.maxWidth < 320) {
            return Column(
              children: [
                chart,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: details),
              ],
            );
          }
          return Row(
            children: [
              chart,
              const SizedBox(width: 14),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    DashboardProvider dashboard,
  ) {
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                    fontSize: 18,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...dashboard.recentActivities.map(
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
                        activity.name
                            .split(' ')
                            .where((part) => part.isNotEmpty)
                            .take(2)
                            .map((part) => part[0])
                            .join(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activity.timestamp} · ${activity.institution}',
                            style: const TextStyle(
                              color: AppTheme.subtitleGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: activity.result == 'Positive'
                                ? AppTheme.red.withValues(alpha: 0.1)
                                : AppTheme.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            activity.result,
                            style: TextStyle(
                              color: activity.result == 'Positive'
                                  ? AppTheme.red
                                  : AppTheme.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activity.confidence}% confidence',
                          style: const TextStyle(
                            color: AppTheme.subtitleGrey,
                            fontSize: 12,
                          ),
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

class _StatusKey extends StatelessWidget {
  const _StatusKey({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.subtitleGrey),
        ),
      ],
    );
  }
}

class TrendsChartPainter extends CustomPainter {
  final List<TrendDataPoint> data;

  TrendsChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final double padding = 40.0;
    final double chartWidth = size.width - padding - 20;
    final double chartHeight = size.height - padding - 20;

    final gridPaint = Paint()
      ..color = AppTheme.borderLight
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: AppTheme.subtitleGrey,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // Find max value for y-axis
    int maxValue = 0;
    for (var point in data) {
      if (point.totalDiagnoses > maxValue) maxValue = point.totalDiagnoses;
      if (point.totalPatients > maxValue) maxValue = point.totalPatients;
    }
    // Round up to nearest multiple of 7
    maxValue = ((maxValue / 7).ceil()) * 7;
    if (maxValue == 0) maxValue = 7;
    final yStep = maxValue / 4;

    // Draw Grid Lines & Labels (Y-Axis)
    for (int i = 0; i <= 4; i++) {
      double y = padding + (chartHeight - (i * chartHeight / 4));
      canvas.drawLine(
        Offset(padding, y),
        Offset(padding + chartWidth, y),
        gridPaint,
      );

      // Y-Axis Labels
      final textSpan = TextSpan(
        text: '${(i * yStep).toInt()}',
        style: labelStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    // X-Axis Labels
    for (int i = 0; i < data.length; i++) {
      double x = padding + (i * chartWidth / (data.length - 1));

      final textSpan = TextSpan(text: data[i].date, style: labelStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, padding + chartHeight + 10),
      );
    }

    // Normalize data
    final diagnosesData = data.map((d) => d.totalDiagnoses / maxValue).toList();
    final patientsData = data.map((d) => d.totalPatients / maxValue).toList();

    _drawLine(
      canvas,
      chartWidth,
      chartHeight,
      padding,
      diagnosesData,
      AppTheme.primaryDark,
      dashed: false,
    );
    _drawLine(
      canvas,
      chartWidth,
      chartHeight,
      padding,
      patientsData,
      AppTheme.navy,
      dashed: true,
    );
  }

  void _drawLine(
    Canvas canvas,
    double width,
    double height,
    double padding,
    List<double> data,
    Color color, {
    required bool dashed,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    for (int i = 0; i < data.length; i++) {
      double x = padding + (i * width / (data.length - 1));
      double y = padding + (height - (data[i] * height));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        double prevX = padding + ((i - 1) * width / (data.length - 1));
        double prevY = padding + (height - (data[i - 1] * height));

        // Use cubic bezier for smooth curves
        path.cubicTo(
          prevX + (x - prevX) / 2,
          prevY,
          prevX + (x - prevX) / 2,
          y,
          x,
          y,
        );
      }
    }

    if (dashed) {
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          canvas.drawPath(metric.extractPath(distance, distance + 8), paint);
          distance += 13;
        }
      }
    } else {
      canvas.drawPath(path, paint);
    }

    // Draw data points
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotOutlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < data.length; i++) {
      double x = padding + (i * width / (data.length - 1));
      double y = padding + (height - (data[i] * height));
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
      canvas.drawCircle(Offset(x, y), 5, dotOutlinePaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
