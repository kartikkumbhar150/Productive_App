import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_theme.dart';
import '../core/time_utils.dart';
import '../providers/productivity_provider.dart';
import '../widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  final _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    Future.microtask(() {
      if (!mounted) return;
      final provider = context.read<ProductivityProvider>();
      provider.loadDailyData(DateTime.now());
      provider.loadWeeklyTrend();
      provider.loadAIInsights();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<ProductivityProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.totalMinutes == 0) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue));
            }

            return FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: AppColors.primaryBlue,
                onRefresh: () async {
                  await provider.loadDailyData(DateTime.now());
                  await provider.loadWeeklyTrend();
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    // ── Hero section ────────────────────────────────────
                    _buildHeroSection(provider),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Live metric chips
                          _buildMetricChips(provider),
                          const SizedBox(height: 20),

                          // Task Checklist
                          _buildTaskChecklist(provider),
                          const SizedBox(height: 16),

                          // Donut Chart
                          CollapsibleCard(
                            title: 'Time by Category',
                            icon: Icons.donut_large_rounded,
                            iconColor: AppColors.primaryPurple,
                            child: _buildDonutChart(provider),
                          ),
                          const SizedBox(height: 16),

                          // Productivity Split
                          CollapsibleCard(
                            title: 'Productivity Split',
                            icon: Icons.pie_chart_rounded,
                            iconColor: AppColors.primaryGreen,
                            child: _buildProductivityPie(provider),
                          ),
                          const SizedBox(height: 16),

                          if (provider.weeklyTrendLoaded) ...[
                            CollapsibleCard(
                              title: 'Tasks Overview',
                              icon: Icons.bar_chart_rounded,
                              iconColor: AppColors.softOrange,
                              child: _buildTasksBarChart(provider),
                            ),
                            const SizedBox(height: 16),
                            CollapsibleCard(
                              title: 'Weekly Trend',
                              icon: Icons.show_chart_rounded,
                              iconColor: AppColors.primaryBlue,
                              child: _buildProductivityLineChart(provider),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (provider.weeklyTrendLoaded &&
                              provider.cumulativeFocus.isNotEmpty) ...[
                            CollapsibleCard(
                              title: 'Cumulative Focus',
                              icon: Icons.stacked_line_chart_rounded,
                              iconColor: AppColors.softTeal,
                              child: _buildCumulativeAreaChart(provider),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (provider.categoryBreakdown.isNotEmpty) ...[
                            CollapsibleCard(
                              title: 'Time vs Productivity',
                              icon: Icons.scatter_plot_rounded,
                              iconColor: AppColors.softLavender,
                              child: _buildScatterPlot(provider),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (provider.aiInsightsLoaded)
                            _buildAIInsightsCard(provider),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Hero Section ──────────────────────────────────────────────────────────

  Widget _buildHeroSection(ProductivityProvider provider) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    final greetingEmoji = now.hour < 12
        ? '☀️'
        : now.hour < 17
            ? '⚡'
            : '🌙';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A73E8),
            const Color(0xFF6C63FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 40, bottom: -30,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Online/offline pill
                      _buildConnectionPill(provider),
                      const SizedBox(height: 12),
                      Text(
                        '$greetingEmoji $greeting',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Progress bar for today
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getScoreLabel(provider.productivityIndex),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${provider.productivityIndex}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: provider.productivityIndex / 100,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.totalMinutes > 0
                                ? '${formatTime(provider.totalMinutes)} tracked today'
                                : 'No time tracked yet',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedScoreRing(
                  score: provider.productivityIndex.toDouble(),
                  size: 90,
                  strokeWidth: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionPill(ProductivityProvider provider) {
    final isOnline = provider.isOnline;
    final pending = provider.pendingSyncCount;
    final label = !isOnline
        ? '⚡ Offline mode'
        : pending > 0
            ? '🔄 $pending unsynced'
            : '✅ All synced';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── Live Metric Chips ────────────────────────────────────────────────────

  Widget _buildMetricChips(ProductivityProvider provider) {
    return Row(
      children: [
        _metricChip(
          '🎯 Focused',
          formatTime(provider.productiveMinutes),
          AppColors.productive,
          provider.productiveMinutes / (provider.totalMinutes > 0 ? provider.totalMinutes : 1),
        ),
        const SizedBox(width: 8),
        _metricChip(
          '💤 Wasted',
          formatTime(provider.wastedMinutes),
          AppColors.wasted,
          provider.wastedMinutes / (provider.totalMinutes > 0 ? provider.totalMinutes : 1),
        ),
        const SizedBox(width: 8),
        _metricChip(
          '⚡ Neutral',
          formatTime(provider.neutralMinutes),
          AppColors.neutral,
          provider.neutralMinutes / (provider.totalMinutes > 0 ? provider.totalMinutes : 1),
        ),
      ],
    );
  }

  Widget _metricChip(
      String label, String value, Color color, double fraction) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.softShadow,
          border: Border.all(
              color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Task Checklist ───────────────────────────────────────────────────────

  Widget _buildTaskChecklist(ProductivityProvider provider) {
    final completed = provider.tasks.where((t) => t.isCompleted).length;
    final total = provider.tasks.length;
    final progress = total > 0 ? completed / total : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist_rounded,
                    color: AppColors.primaryBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Text("Today's Tasks", style: AppTextStyles.h3),
              const Spacer(),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$completed/$total',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          // Completion progress bar
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen),
                  minHeight: 6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...provider.tasks.map((task) => TaskListItem(
                taskName: task.taskName,
                isCompleted: task.isCompleted,
                isLocked: true,
                onToggle: task.isCompleted
                    ? null
                    : () => provider.completeTask(task),
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a task...',
                    hintStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 14, color: AppColors.textHint),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_taskController.text.trim().isNotEmpty) {
                    provider.addTask(_taskController.text.trim(), DateTime.now());
                    _taskController.clear();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent! 🔥';
    if (score >= 60) return 'Great Work! 💪';
    if (score >= 40) return 'Keep Going! ⚡';
    if (score >= 20) return 'Needs Focus 🎯';
    return 'Get Started! 🚀';
  }

  // ─── Donut Chart ──────────────────────────────────────────────────────────

  Widget _buildDonutChart(ProductivityProvider provider) {
    final data = provider.categoryBreakdown;
    if (data.isEmpty) {
      return _emptyChartPlaceholder('Track time to see category breakdown');
    }

    final entries = data.entries.toList();
    final total =
        entries.fold<double>(0, (s, e) => s + (e.value as num));

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              sections: entries.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final value = (e.value as num).toDouble();
                final color = AppColors.categoryColor(e.key, i);
                return PieChartSectionData(
                  value: value,
                  color: color,
                  radius: 35,
                  showTitle: false,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: entries.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = total > 0
                ? ((e.value as num) / total * 100).toStringAsFixed(0)
                : '0';
            return _legendItem(
              e.key,
              AppColors.categoryColor(e.key, i),
              '${formatTime((e.value as num).toInt())} ($pct%)',
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Productivity Pie ─────────────────────────────────────────────────────

  Widget _buildProductivityPie(ProductivityProvider provider) {
    final prod = provider.productiveMinutes.toDouble();
    final neutral = provider.neutralMinutes.toDouble();
    final wasted = provider.wastedMinutes.toDouble();
    final total = prod + neutral + wasted;

    if (total == 0) {
      return _emptyChartPlaceholder('Track time to see productivity split');
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                    value: prod,
                    color: AppColors.productive,
                    radius: 30,
                    showTitle: false),
                PieChartSectionData(
                    value: neutral,
                    color: AppColors.neutral,
                    radius: 30,
                    showTitle: false),
                PieChartSectionData(
                    value: wasted,
                    color: AppColors.wasted,
                    radius: 30,
                    showTitle: false),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem('Productive', AppColors.productive,
                '${(prod / total * 100).toStringAsFixed(0)}%'),
            const SizedBox(width: 16),
            _legendItem('Neutral', AppColors.neutral,
                '${(neutral / total * 100).toStringAsFixed(0)}%'),
            const SizedBox(width: 16),
            _legendItem('Wasted', AppColors.wasted,
                '${(wasted / total * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ],
    );
  }

  // ─── Bar Chart ────────────────────────────────────────────────────────────

  Widget _buildTasksBarChart(ProductivityProvider provider) {
    final trend = provider.weeklyTrend;
    if (trend.isEmpty) {
      return _emptyChartPlaceholder('Weekly data will appear here');
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = rodIndex == 0 ? 'Done' : 'Missed';
                return BarTooltipItem(
                  '$label: ${rod.toY.toInt()}',
                  AppTextStyles.caption
                      .copyWith(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= trend.length) return const Text('');
                  final date = trend[i]['date'] as String;
                  const dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                  final dt = DateTime.tryParse(date);
                  return Text(
                    dt != null ? dayNames[dt.weekday % 7] : '',
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          barGroups: trend.asMap().entries.map((entry) {
            final i = entry.key;
            final day = entry.value;
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY:
                    (day['tasksCompleted'] as num?)?.toDouble() ?? 0,
                color: AppColors.primaryGreen,
                width: 10,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: (day['tasksMissed'] as num?)?.toDouble() ?? 0,
                color: AppColors.wasted,
                width: 10,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ─── Line Chart ───────────────────────────────────────────────────────────

  Widget _buildProductivityLineChart(ProductivityProvider provider) {
    final trend = provider.weeklyTrend;
    if (trend.isEmpty) {
      return _emptyChartPlaceholder('Weekly data will appear here');
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= trend.length) return const Text('');
                  final date = trend[i]['date'] as String;
                  final dt = DateTime.tryParse(date);
                  const dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                  return Text(
                    dt != null ? dayNames[dt.weekday % 7] : '',
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: trend.asMap().entries.map((e) {
                return FlSpot(
                  e.key.toDouble(),
                  (e.value['productivityIndex'] as num?)?.toDouble() ?? 0,
                );
              }).toList(),
              color: AppColors.primaryBlue,
              barWidth: 3,
              isCurved: true,
              curveSmoothness: 0.3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primaryBlue,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
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

  // ─── Area Chart ───────────────────────────────────────────────────────────

  Widget _buildCumulativeAreaChart(ProductivityProvider provider) {
    final data = provider.cumulativeFocus;
    if (data.isEmpty) {
      return _emptyChartPlaceholder('Focus data will appear here');
    }

    final maxY = data.fold<double>(
        0,
        (m, d) =>
            (d['cumulativeMinutes'] as num).toDouble() > m
                ? (d['cumulativeMinutes'] as num).toDouble()
                : m);

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  formatTime(value.toInt()),
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const Text('');
                  final date = data[i]['date'] as String;
                  return Text(
                    date.substring(8, 10),
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          minY: 0,
          maxY: maxY > 0 ? maxY * 1.2 : 100,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) {
                return FlSpot(
                  e.key.toDouble(),
                  (e.value['cumulativeMinutes'] as num).toDouble(),
                );
              }).toList(),
              color: AppColors.softTeal,
              barWidth: 3,
              isCurved: true,
              curveSmoothness: 0.3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.softTeal.withValues(alpha: 0.3),
                    AppColors.softTeal.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Scatter Plot ─────────────────────────────────────────────────────────

  Widget _buildScatterPlot(ProductivityProvider provider) {
    final catBreakdown = provider.categoryBreakdown;
    final prodByCat = provider.productivityByCategory;

    if (catBreakdown.isEmpty) {
      return _emptyChartPlaceholder('Category data will appear here');
    }

    final spots = <ScatterSpot>[];
    final categories = catBreakdown.keys.toList();

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final totalMin = (catBreakdown[cat] as num?)?.toDouble() ?? 0;
      final prodData = prodByCat[cat];
      double prodRate = 0;
      if (prodData != null) {
        final prodMin = (prodData['productive'] as num?)?.toDouble() ?? 0;
        prodRate = totalMin > 0 ? (prodMin / totalMin * 100) : 0;
      }
      spots.add(ScatterSpot(
        totalMin, prodRate,
        dotPainter: FlDotCirclePainter(
          radius: 8,
          color: AppColors.categoryColor(cat, i).withValues(alpha: 0.8),
          strokeWidth: 2,
          strokeColor: AppColors.categoryColor(cat, i),
        ),
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: ScatterChart(
            ScatterChartData(
              scatterSpots: spots,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, m) => Text('${v.toInt()}%',
                        style: AppTextStyles.caption.copyWith(fontSize: 9)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) => Text('${v.toInt()}m',
                        style: AppTextStyles.caption.copyWith(fontSize: 9)),
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              minY: 0, maxY: 100,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('X = Time spent  •  Y = Productivity %',
            style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  // ─── AI Insights ──────────────────────────────────────────────────────────

  Widget _buildAIInsightsCard(ProductivityProvider provider) {
    final data = provider.aiInsightsData;
    final insights =
        List<Map<String, dynamic>>.from(data['insights'] ?? []);
    final summary = data['summary'] as String? ?? '';

    return CollapsibleCard(
      title: 'AI Insights',
      icon: Icons.auto_awesome_rounded,
      iconColor: AppColors.softYellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(summary,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13, height: 1.4)),
            ),
            const SizedBox(height: 12),
          ],
          ...insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight['icon'] ?? '💡',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight['text'] ?? '',
                      style: AppTextStyles.body
                          .copyWith(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _legendItem(String label, Color color, String value) {
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
        Text('$label $value',
            style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _emptyChartPlaceholder(String text) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined,
              size: 32, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
