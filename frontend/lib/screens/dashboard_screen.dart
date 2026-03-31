import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../providers/productivity_provider.dart';

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
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    Future.microtask(
        () => context.read<ProductivityProvider>().loadDailyData(DateTime.now()));
  }

  @override
  void dispose() {
    _animController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  static const List<Color> _categoryColors = [
    Color(0xFF6C8EEF),
    Color(0xFF6BCFA1),
    Color(0xFF9B8FEF),
    Color(0xFFEFAB6B),
    Color(0xFFEF8FA3),
    Color(0xFF5CC2E0),
    Color(0xFFE88FEF),
    Color(0xFFA3D977),
    Color(0xFFEFD36B),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Consumer<ProductivityProvider>(
            builder: (context, provider, _) {
              final totalSlots = provider.slots.length;
              final productiveSlots = provider.slots
                  .where((s) => s.type.toString().endsWith('productive'))
                  .length;
              final wastedSlots = provider.slots
                  .where((s) => s.type.toString().endsWith('wasted'))
                  .length;
              final neutralSlots =
                  totalSlots - productiveSlots - wastedSlots;
              final prodPercent = totalSlots > 0
                  ? (productiveSlots / totalSlots) * 100
                  : 0.0;

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good ${_getGreeting()}',
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text('Dashboard', style: AppTextStyles.h1),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.buttonShadow,
                            ),
                            child: Text(
                              _formattedDate(),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Stats Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Productive',
                              value: '${(productiveSlots * 20)}m',
                              subtitle:
                                  '${prodPercent.toStringAsFixed(0)}% of time',
                              icon: Icons.trending_up_rounded,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: StatCard(
                              title: 'Wasted',
                              value: '${(wastedSlots * 20)}m',
                              icon: Icons.trending_down_rounded,
                              color: AppColors.softPink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Neutral',
                              value: '${(neutralSlots * 20)}m',
                              icon: Icons.remove_circle_outline_rounded,
                              color: AppColors.softOrange,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: StatCard(
                              title: 'Tasks',
                              value: '${provider.tasks.length}',
                              subtitle:
                                  '${provider.tasks.where((t) => t.isCompleted).length} done',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // ─── PIE CHART: Productivity Breakdown ────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Today's Focus",
                                    style: AppTextStyles.h3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${prodPercent.toStringAsFixed(0)}%',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 180,
                              child: totalSlots == 0
                                  ? _emptyChartPlaceholder(
                                      Icons.pie_chart_outline_rounded,
                                      'No data yet',
                                      'Start tracking your time blocks')
                                  : PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 45,
                                        sections: [
                                          PieChartSectionData(
                                            color: AppColors.primaryGreen,
                                            value: productiveSlots
                                                .toDouble(),
                                            title:
                                                '${(productiveSlots * 20)}m',
                                            titleStyle: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white),
                                            radius: 30,
                                          ),
                                          PieChartSectionData(
                                            color: AppColors.softOrange,
                                            value:
                                                neutralSlots.toDouble(),
                                            title:
                                                '${(neutralSlots * 20)}m',
                                            titleStyle: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white),
                                            radius: 26,
                                          ),
                                          PieChartSectionData(
                                            color: AppColors.softPink,
                                            value:
                                                wastedSlots.toDouble(),
                                            title:
                                                '${(wastedSlots * 20)}m',
                                            titleStyle: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white),
                                            radius: 26,
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _legendItem(
                                    'Productive', AppColors.primaryGreen),
                                _legendItem(
                                    'Neutral', AppColors.softOrange),
                                _legendItem('Wasted', AppColors.softPink),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ─── BAR CHART: Time by Category ──────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.bar_chart_rounded,
                                      color: AppColors.primaryBlue,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text('Time by Category',
                                    style: AppTextStyles.h3),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Minutes spent per category today',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 20),
                            _buildCategoryBars(provider.categoryBreakdown),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ─── BAR CHART: Time per Task ─────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.stacked_bar_chart_rounded,
                                      color: AppColors.primaryPurple,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text('Time per Task',
                                    style: AppTextStyles.h3),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'How much time spent on each task',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 20),
                            _buildTaskBars(provider.taskBreakdown),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ─── STACKED CHART: Productivity per Category ─
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.analytics_rounded,
                                      color: AppColors.primaryGreen,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text('Productivity by Category',
                                    style: AppTextStyles.h3),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Productive / Neutral / Wasted per category',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 20),
                            _buildProductivityByCategoryChart(
                                provider.productivityByCategory),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _legendItem(
                                    'Productive', AppColors.primaryGreen),
                                _legendItem(
                                    'Neutral', AppColors.softOrange),
                                _legendItem(
                                    'Wasted', AppColors.softPink),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ─── AI INSIGHTS CARD ─────────────────────────
                  if (provider.aiInsights.isNotEmpty &&
                      !provider.aiInsights.contains('GROQ_API_KEY'))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppShadows.buttonShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withOpacity(0.2),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.psychology_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'AI Coach',
                                    style: AppTextStyles.h3
                                        .copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                provider.aiInsights,
                                style: AppTextStyles.body.copyWith(
                                  color:
                                      Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // Tasks Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Today's Tasks",
                              style: AppTextStyles.h3),
                          GestureDetector(
                            onTap: () => _showAddTaskSheet(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
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
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  provider.tasks.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: AppCard(
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.checklist_rounded,
                                        size: 40,
                                        color: AppColors.textHint),
                                    const SizedBox(height: 12),
                                    Text('No tasks yet',
                                        style: AppTextStyles.bodyBold),
                                    const SizedBox(height: 4),
                                    Text('Tap + to add your first task',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final task = provider.tasks[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    boxShadow: AppShadows.softShadow,
                                    border: Border.all(
                                      color: task.isCompleted
                                          ? AppColors.primaryGreen
                                              .withOpacity(0.3)
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (!task.isCompleted) {
                                            provider
                                                .completeTask(task);
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            gradient: task.isCompleted
                                                ? AppColors
                                                    .greenGradient
                                                : null,
                                            color: task.isCompleted
                                                ? null
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    8),
                                            border: task.isCompleted
                                                ? null
                                                : Border.all(
                                                    color: AppColors
                                                        .border,
                                                    width: 1.5),
                                          ),
                                          child: task.isCompleted
                                              ? const Icon(Icons.check,
                                                  size: 16,
                                                  color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          task.taskName,
                                          style: AppTextStyles.bodyBold
                                              .copyWith(
                                            decoration: task.isCompleted
                                                ? TextDecoration
                                                    .lineThrough
                                                : null,
                                            color: task.isCompleted
                                                ? AppColors
                                                    .textTertiary
                                                : AppColors
                                                    .textPrimary,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                          Icons
                                              .lock_outline_rounded,
                                          size: 16,
                                          color: AppColors.textHint),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: provider.tasks.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Chart Builders ────────────────────────────────────

  Widget _emptyChartPlaceholder(
      IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.caption),
          Text(subtitle,
              style: AppTextStyles.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCategoryBars(Map<String, dynamic> breakdown) {
    if (breakdown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _emptyChartPlaceholder(Icons.bar_chart_rounded,
            'No category data', 'Log time blocks to see charts'),
      );
    }

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final maxMinutes = sortedEntries.isNotEmpty
        ? (sortedEntries.first.value as num).toDouble()
        : 1.0;

    return Column(
      children: sortedEntries.asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final entry = mapEntry.value;
        final minutes = (entry.value as num).toDouble();
        final fraction = minutes / maxMinutes;
        final color = _categoryColors[index % _categoryColors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${minutes.toInt()}m',
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 10,
                  backgroundColor: color.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskBars(Map<String, dynamic> breakdown) {
    if (breakdown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _emptyChartPlaceholder(
            Icons.stacked_bar_chart_rounded,
            'No task data',
            'Log time blocks to see task breakdown'),
      );
    }

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final maxMinutes = sortedEntries.isNotEmpty
        ? (sortedEntries.first.value as num).toDouble()
        : 1.0;

    return Column(
      children: sortedEntries.asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final entry = mapEntry.value;
        final minutes = (entry.value as num).toDouble();
        final fraction = minutes / maxMinutes;
        final color = _categoryColors[
            (index + 3) % _categoryColors.length]; // offset palette

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${minutes.toInt()}m',
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 10,
                  backgroundColor: color.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductivityByCategoryChart(
      Map<String, dynamic> productivityByCategory) {
    if (productivityByCategory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _emptyChartPlaceholder(Icons.analytics_rounded,
            'No breakdown data', 'Log time to see productivity per category'),
      );
    }

    return Column(
      children: productivityByCategory.entries.map((entry) {
        final Map<String, dynamic> prodData =
            Map<String, dynamic>.from(entry.value);
        final productive =
            (prodData['productive'] as num?)?.toDouble() ?? 0;
        final neutral =
            (prodData['neutral'] as num?)?.toDouble() ?? 0;
        final wasted = (prodData['wasted'] as num?)?.toDouble() ?? 0;
        final totalCat = productive + neutral + wasted;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${totalCat.toInt()}m total',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      if (productive > 0)
                        Expanded(
                          flex: productive.toInt(),
                          child: Container(
                              color: AppColors.primaryGreen),
                        ),
                      if (neutral > 0)
                        Expanded(
                          flex: neutral.toInt(),
                          child: Container(
                              color: AppColors.softOrange),
                        ),
                      if (wasted > 0)
                        Expanded(
                          flex: wasted.toInt(),
                          child: Container(
                              color: AppColors.softPink),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (productive > 0)
                    Text(
                      '${productive.toInt()}m ✨  ',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryGreen, fontSize: 10),
                    ),
                  if (neutral > 0)
                    Text(
                      '${neutral.toInt()}m ⚡  ',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.softOrange, fontSize: 10),
                    ),
                  if (wasted > 0)
                    Text(
                      '${wasted.toInt()}m 💤  ',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.softPink, fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.caption.copyWith(fontSize: 12)),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning ☀️';
    if (hour < 17) return 'Afternoon 🌤️';
    return 'Evening 🌙';
  }

  String _formattedDate() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}';
  }

  void _showAddTaskSheet(BuildContext context) {
    _taskController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Add New Task', style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text(
              'Once added, tasks cannot be edited or deleted',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.softPink,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              hint: 'What do you need to do?',
              prefixIcon: Icons.edit_outlined,
              controller: _taskController,
            ),
            const SizedBox(height: 20),
            GradientButton(
              text: 'Add Task (Immutable)',
              onPressed: () {
                if (_taskController.text.isNotEmpty) {
                  context
                      .read<ProductivityProvider>()
                      .addTask(_taskController.text, DateTime.now());
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
