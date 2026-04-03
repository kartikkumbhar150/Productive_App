import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_theme.dart';
import '../core/time_utils.dart';
import '../services/api_service.dart';
import '../widgets/app_widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _report;
  bool _isLoading = false;
  String _selectedChip = '7D';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadReport('7D');
  }

  DateTimeRange _chipToRange(String chip) {
    final now = DateTime.now();
    switch (chip) {
      case '7D':
        return DateTimeRange(
            start: now.subtract(const Duration(days: 6)), end: now);
      case '30D':
        return DateTimeRange(
            start: now.subtract(const Duration(days: 29)), end: now);
      case '90D':
        return DateTimeRange(
            start: now.subtract(const Duration(days: 89)), end: now);
      default:
        return _customRange ??
            DateTimeRange(
                start: now.subtract(const Duration(days: 6)), end: now);
    }
  }

  Future<void> _loadReport(String chip) async {
    setState(() {
      _selectedChip = chip;
      _isLoading = true;
    });

    try {
      final range = _chipToRange(chip);
      final data = await _api.getReport(range.start, range.end);
      setState(() => _report = data);
    } catch (e) {
      debugPrint('Report error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _selectedChip = 'Custom';
      });
      _loadReport('Custom');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppShadows.softShadow,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Reports', style: AppTextStyles.h1),
                ],
              ),
            ),

            // Period chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _periodChip('7D'),
                  const SizedBox(width: 8),
                  _periodChip('30D'),
                  const SizedBox(width: 8),
                  _periodChip('90D'),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _pickCustomRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedChip == 'Custom'
                            ? AppColors.primaryBlue.withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedChip == 'Custom'
                              ? AppColors.primaryBlue
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 14,
                              color: _selectedChip == 'Custom'
                                  ? AppColors.primaryBlue
                                  : AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('Custom',
                              style: AppTextStyles.caption.copyWith(
                                color: _selectedChip == 'Custom'
                                    ? AppColors.primaryBlue
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryBlue))
                  : _report == null
                      ? _emptyState()
                      : _buildReportContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String label) {
    final isActive = _selectedChip == label;
    return GestureDetector(
      onTap: () => _loadReport(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primaryBlue : AppColors.border,
          ),
        ),
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
              color: isActive ? AppColors.primaryBlue : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            )),
      ),
    );
  }

  Widget _buildReportContent() {
    final r = _report!;
    final dailyBreakdown = List<Map<String, dynamic>>.from(
        r['dailyBreakdown'] ?? []);
    final hourlyProductivity = List<Map<String, dynamic>>.from(
        r['hourlyProductivity'] ?? []);
    final weekdayBreakdown = List<Map<String, dynamic>>.from(
        r['weekdayBreakdown'] ?? []);
    final categoryBreakdown = Map<String, dynamic>.from(
        r['categoryBreakdown'] ?? {});
    final prodByCat = Map<String, dynamic>.from(
        r['productivityByCategory'] ?? {});

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // Summary stats
        _buildSummaryStats(r),
        const SizedBox(height: 16),

        // Daily Productivity Trend
        if (dailyBreakdown.isNotEmpty)
          CollapsibleCard(
            title: 'Daily Trend',
            icon: Icons.show_chart_rounded,
            iconColor: AppColors.primaryBlue,
            child: _buildDailyTrendChart(dailyBreakdown),
          ),
        if (dailyBreakdown.isNotEmpty) const SizedBox(height: 16),

        // Category Performance — Stacked Bar
        if (prodByCat.isNotEmpty)
          CollapsibleCard(
            title: 'Category Performance',
            icon: Icons.stacked_bar_chart_rounded,
            iconColor: AppColors.primaryPurple,
            child: _buildCategoryStackedBar(prodByCat),
          ),
        if (prodByCat.isNotEmpty) const SizedBox(height: 16),

        // Heatmap - Hourly Productivity
        if (hourlyProductivity.isNotEmpty)
          CollapsibleCard(
            title: 'Hourly Heatmap',
            icon: Icons.grid_view_rounded,
            iconColor: AppColors.primaryGreen,
            child: _buildHourlyHeatmap(hourlyProductivity),
          ),
        if (hourlyProductivity.isNotEmpty) const SizedBox(height: 16),

        // Missed Tasks Analysis
        if (dailyBreakdown.isNotEmpty)
          CollapsibleCard(
            title: 'Tasks Analysis',
            icon: Icons.fact_check_rounded,
            iconColor: AppColors.softOrange,
            child: _buildMissedTasksAnalysis(r, dailyBreakdown),
          ),
        if (dailyBreakdown.isNotEmpty) const SizedBox(height: 16),

        // Weekday Breakdown
        if (weekdayBreakdown.isNotEmpty)
          CollapsibleCard(
            title: 'Weekday Patterns',
            icon: Icons.calendar_view_week_rounded,
            iconColor: AppColors.softTeal,
            child: _buildWeekdayChart(weekdayBreakdown),
          ),
        if (weekdayBreakdown.isNotEmpty) const SizedBox(height: 16),

        // Trend Forecast
        if (dailyBreakdown.length >= 3)
          CollapsibleCard(
            title: 'Trend Forecast',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.softLavender,
            child: _buildTrendForecast(dailyBreakdown),
          ),

        // Category Donut
        if (categoryBreakdown.isNotEmpty) ...[
          const SizedBox(height: 16),
          CollapsibleCard(
            title: 'Time Distribution',
            icon: Icons.donut_large_rounded,
            iconColor: AppColors.softPink,
            child: _buildCategoryDonut(categoryBreakdown),
          ),
        ],
      ],
    );
  }

  // ─── Summary Stats ─────────────────────────────────────
  Widget _buildSummaryStats(Map<String, dynamic> r) {
    final prodIdx = r['productivityIndex'] ?? 0;

    return AppCard(
      child: Row(
        children: [
          AnimatedScoreRing(
            score: (prodIdx is int ? prodIdx : (prodIdx as num).toInt())
                .toDouble(),
            size: 100,
            strokeWidth: 9,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Period Summary',
                    style: AppTextStyles.label.copyWith(letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _statRow('Total Time', formatTime(
                    (r['totalMinutes'] as num?)?.toInt() ?? 0)),
                _statRow('Productive', formatTime(
                    (r['productiveMinutes'] as num?)?.toInt() ?? 0)),
                _statRow('Tasks Done',
                    '${r['completedTasks'] ?? 0}/${r['totalTasks'] ?? 0}'),
                _statRow('Days', '${r['totalDays'] ?? 0}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Daily Trend Chart ─────────────────────────────────
  Widget _buildDailyTrendChart(List<Map<String, dynamic>> daily) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: AppColors.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 28,
              getTitlesWidget: (v, m) => Text('${v.toInt()}',
                  style: AppTextStyles.caption.copyWith(fontSize: 9)),
            )),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              interval: (daily.length / 6).ceilToDouble().clamp(1, 100),
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= daily.length) return const Text('');
                final d = daily[i]['date'] as String;
                return Text(d.substring(5, 10),
                    style: AppTextStyles.caption.copyWith(fontSize: 8));
              },
            )),
          ),
          minY: 0, maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: daily.asMap().entries.map((e) => FlSpot(
                e.key.toDouble(),
                (e.value['productivityPercentage'] as num?)?.toDouble() ?? 0,
              )).toList(),
              color: AppColors.primaryBlue,
              barWidth: 2.5,
              isCurved: true,
              curveSmoothness: 0.25,
              dotData: FlDotData(show: daily.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category Stacked Bar ──────────────────────────────
  Widget _buildCategoryStackedBar(Map<String, dynamic> prodByCat) {
    final cats = prodByCat.keys.toList();
    if (cats.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= cats.length) return const Text('');
                    return Text(cats[i].length > 6
                        ? '${cats[i].substring(0, 5)}.'
                        : cats[i],
                        style: AppTextStyles.caption.copyWith(fontSize: 9));
                  },
                )),
              ),
              barGroups: cats.asMap().entries.map((entry) {
                final i = entry.key;
                final cat = entry.value;
                final data = prodByCat[cat] as Map<String, dynamic>? ?? {};
                final prod = (data['productive'] as num?)?.toDouble() ?? 0;
                final neut = (data['neutral'] as num?)?.toDouble() ?? 0;
                final wast = (data['wasted'] as num?)?.toDouble() ?? 0;
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: prod + neut + wast,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                    rodStackItems: [
                      BarChartRodStackItem(0, prod, AppColors.productive),
                      BarChartRodStackItem(
                          prod, prod + neut, AppColors.neutral),
                      BarChartRodStackItem(
                          prod + neut, prod + neut + wast, AppColors.wasted),
                    ],
                    color: Colors.transparent,
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot('Productive', AppColors.productive),
            const SizedBox(width: 12),
            _legendDot('Neutral', AppColors.neutral),
            const SizedBox(width: 12),
            _legendDot('Wasted', AppColors.wasted),
          ],
        ),
      ],
    );
  }

  // ─── Hourly Heatmap ────────────────────────────────────
  Widget _buildHourlyHeatmap(List<Map<String, dynamic>> hourly) {
    // Filter to waking hours (6-23)
    final filtered = hourly.where((h) {
      final hour = (h['hour'] as num?)?.toInt() ?? 0;
      return hour >= 6 && hour <= 23;
    }).toList();

    final maxTotal = filtered.fold<double>(
        1, (m, h) => ((h['total'] as num?)?.toDouble() ?? 0) > m
            ? (h['total'] as num?)!.toDouble()
            : m);

    return Column(
      children: [
        ...List.generate((filtered.length / 6).ceil(), (row) {
          final startIdx = row * 6;
          final endIdx = (startIdx + 6).clamp(0, filtered.length);
          final cells = filtered.sublist(startIdx, endIdx);

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: cells.map((h) {
                final hour = (h['hour'] as num?)?.toInt() ?? 0;
                final total = (h['total'] as num?)?.toDouble() ?? 0;
                final productive = (h['productive'] as num?)?.toDouble() ?? 0;
                final intensity = total / maxTotal;

                Color cellColor;
                if (total == 0) {
                  cellColor = AppColors.border;
                } else {
                  final prodRate = productive / total;
                  if (prodRate >= 0.7) {
                    cellColor = AppColors.productive.withValues(
                        alpha: 0.3 + (intensity * 0.7));
                  } else if (prodRate >= 0.4) {
                    cellColor = AppColors.neutral.withValues(
                        alpha: 0.3 + (intensity * 0.7));
                  } else {
                    cellColor = AppColors.wasted.withValues(
                        alpha: 0.3 + (intensity * 0.7));
                  }
                }

                return Expanded(
                  child: Tooltip(
                    message: '${hour}:00 — ${formatTime(total.toInt())}',
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      height: 36,
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${hour}h',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9,
                            color: total > 0
                                ? Colors.white
                                : AppColors.textHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot('Productive', AppColors.productive),
            const SizedBox(width: 10),
            _legendDot('Mixed', AppColors.neutral),
            const SizedBox(width: 10),
            _legendDot('Unproductive', AppColors.wasted),
            const SizedBox(width: 10),
            _legendDot('No data', AppColors.border),
          ],
        ),
      ],
    );
  }

  // ─── Missed Tasks Analysis ─────────────────────────────
  Widget _buildMissedTasksAnalysis(
      Map<String, dynamic> r, List<Map<String, dynamic>> daily) {
    final completed = (r['completedTasks'] as num?)?.toInt() ?? 0;
    final total = (r['totalTasks'] as num?)?.toInt() ?? 0;
    final missed = total - completed;

    return Column(
      children: [
        // Pie: completed vs missed
        if (total > 0)
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(
                    value: completed.toDouble(),
                    color: AppColors.primaryGreen,
                    radius: 28,
                    title: '$completed',
                    titleStyle: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  PieChartSectionData(
                    value: missed.toDouble(),
                    color: AppColors.wasted,
                    radius: 28,
                    title: '$missed',
                    titleStyle: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot('Completed ($completed)', AppColors.primaryGreen),
            const SizedBox(width: 16),
            _legendDot('Missed ($missed)', AppColors.wasted),
          ],
        ),
        const SizedBox(height: 12),

        // Bar: daily missed
        if (daily.any((d) => ((d['tasksMissed'] as num?)?.toInt() ?? 0) > 0))
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    interval: (daily.length / 5).ceilToDouble().clamp(1, 100),
                    getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      if (i < 0 || i >= daily.length) return const Text('');
                      return Text(
                        (daily[i]['date'] as String).substring(8, 10),
                        style: AppTextStyles.caption.copyWith(fontSize: 9),
                      );
                    },
                  )),
                ),
                barGroups: daily.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(
                      toY: (e.value['tasksMissed'] as num?)?.toDouble() ?? 0,
                      color: AppColors.wasted.withValues(alpha: 0.7),
                      width: daily.length > 14 ? 4 : 8,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3)),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Weekday Chart ─────────────────────────────────────
  Widget _buildWeekdayChart(List<Map<String, dynamic>> weekday) {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= weekday.length) return const Text('');
                return Text(weekday[i]['day'] ?? '',
                    style: AppTextStyles.caption.copyWith(fontSize: 10));
              },
            )),
          ),
          barGroups: weekday.asMap().entries.map((e) {
            final d = e.value;
            final prod = (d['avgProductive'] as num?)?.toDouble() ?? 0;
            final neut = (d['avgNeutral'] as num?)?.toDouble() ?? 0;
            final wast = (d['avgWasted'] as num?)?.toDouble() ?? 0;
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: prod + neut + wast,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                rodStackItems: [
                  BarChartRodStackItem(0, prod, AppColors.productive),
                  BarChartRodStackItem(prod, prod + neut, AppColors.neutral),
                  BarChartRodStackItem(
                      prod + neut, prod + neut + wast, AppColors.wasted),
                ],
                color: Colors.transparent,
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ─── Trend Forecast ────────────────────────────────────
  Widget _buildTrendForecast(List<Map<String, dynamic>> daily) {
    // Simple linear regression on productivity percentages
    final values = daily
        .map((d) => (d['productivityPercentage'] as num?)?.toDouble() ?? 0)
        .toList();

    if (values.length < 3) {
      return const SizedBox.shrink();
    }

    // Compute linear regression
    final n = values.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Generate forecast spots
    final allSpots = <FlSpot>[];
    for (int i = 0; i < n; i++) {
      allSpots.add(FlSpot(i.toDouble(), values[i]));
    }

    final forecastSpots = <FlSpot>[];
    forecastSpots.add(FlSpot((n - 1).toDouble(), values.last));
    for (int i = 0; i < 3; i++) {
      final predicted = (slope * (n + i) + intercept).clamp(0, 100);
      forecastSpots.add(FlSpot((n + i).toDouble(), predicted.toDouble()));
    }

    final trendDirection =
        slope > 0.5 ? '📈 Upward' : slope < -0.5 ? '📉 Downward' : '➡️ Stable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.softLavender.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Trend: $trendDirection  •  Next 3 days forecast based on linear regression',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 28,
                  getTitlesWidget: (v, m) => Text('${v.toInt()}',
                      style: AppTextStyles.caption.copyWith(fontSize: 9)),
                )),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              minY: 0, maxY: 100,
              lineBarsData: [
                // Actual data
                LineChartBarData(
                  spots: allSpots,
                  color: AppColors.primaryBlue,
                  barWidth: 2.5,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primaryBlue.withValues(alpha: 0.05),
                  ),
                ),
                // Forecast
                LineChartBarData(
                  spots: forecastSpots,
                  color: AppColors.softLavender,
                  barWidth: 2,
                  isCurved: true,
                  dashArray: [6, 4],
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.softLavender,
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot('Actual', AppColors.primaryBlue),
            const SizedBox(width: 12),
            _legendDot('Forecast', AppColors.softLavender),
          ],
        ),
      ],
    );
  }

  // ─── Category Donut ────────────────────────────────────
  Widget _buildCategoryDonut(Map<String, dynamic> data) {
    final entries = data.entries.toList();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 45,
              sections: entries.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return PieChartSectionData(
                  value: (e.value as num).toDouble(),
                  color: AppColors.categoryColor(e.key, i),
                  radius: 30,
                  showTitle: false,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10, runSpacing: 4,
          children: entries.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return _legendDot(
              '${e.key} (${formatTime((e.value as num).toInt())})',
              AppColors.categoryColor(e.key, i),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('No data for this period',
              style: AppTextStyles.body),
        ],
      ),
    );
  }
}
