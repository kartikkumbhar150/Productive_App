import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/time_utils.dart';
import '../models/time_slot.dart';
import '../providers/productivity_provider.dart';
import '../widgets/app_widgets.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animController;
  bool _showActual = true;

  // Multi-select state
  bool _isMultiSelectMode = false;
  final Set<String> _selectedRanges = {};

  List<String> get _timeBlocks {
    final blocks = <String>[];
    for (int h = 0; h < 24; h++) {
      for (int m = 0; m < 60; m += 20) {
        final start = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        final endM = m + 20;
        final endH = endM >= 60 ? h + 1 : h;
        final endMin = endM >= 60 ? 0 : endM;
        final end = '${endH.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
        blocks.add('$start-$end');
      }
    }
    return blocks;
  }

  int get _currentBlockIndex {
    final now = DateTime.now();
    return (now.hour * 3) + (now.minute ~/ 20);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    Future.microtask(() {
      if (!mounted) return;
      context.read<ProductivityProvider>().loadDailyData(DateTime.now());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentBlock();
    });
  }

  void _scrollToCurrentBlock() {
    final targetOffset = (_currentBlockIndex * 78.0) - 200;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedRanges.clear();
    });
  }

  void _onBlockLongPress(String timeRange) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isMultiSelectMode = true;
      _selectedRanges.add(timeRange);
    });
  }

  void _onBlockTapInMultiSelect(String timeRange) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedRanges.contains(timeRange)) {
        _selectedRanges.remove(timeRange);
        if (_selectedRanges.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedRanges.add(timeRange);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<ProductivityProvider>(
          builder: (context, provider, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(provider),
                    _buildSummaryStrip(provider),
                    const SizedBox(height: 8),
                    _buildViewToggle(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          _buildTimeline(provider),
                          if (provider.isLoading && provider.slots.isEmpty)
                            const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primaryBlue)),
                          if (provider.isBackgroundRefreshing)
                            const Positioned(
                              top: 0, left: 0, right: 0,
                              child: LinearProgressIndicator(
                                color: AppColors.primaryBlue,
                                backgroundColor: Colors.transparent,
                                minHeight: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildCategoryLegend(provider),
                  ],
                ),

                // Multi-select bottom action bar
                if (_isMultiSelectMode)
                  _buildMultiSelectBar(provider),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _isMultiSelectMode
          ? null
          : FloatingActionButton(
              onPressed: _scrollToCurrentBlock,
              backgroundColor: AppColors.primaryBlue,
              child: const Icon(Icons.my_location_rounded, color: Colors.white),
            ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(ProductivityProvider provider) {
    final now = DateTime.now();
    final dayNames = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
    ];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Timeline', style: AppTextStyles.h1),
              const SizedBox(height: 2),
              Text(
                '${dayNames[now.weekday % 7]}, ${now.day} ${monthNames[now.month - 1]}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const Spacer(),
          // Offline / pending sync pill
          if (!provider.isOnline || provider.pendingSyncCount > 0)
            _buildSyncPill(provider),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_currentBlockIndex/72 blocks',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncPill(ProductivityProvider provider) {
    final isOnline = provider.isOnline;
    final count = provider.pendingSyncCount;
    final color = isOnline
        ? (count > 0 ? AppColors.softOrange : AppColors.productive)
        : AppColors.wasted;
    final label = !isOnline
        ? 'Offline'
        : count > 0
            ? '$count pending'
            : 'Synced';
    final icon = !isOnline
        ? Icons.wifi_off_rounded
        : count > 0
            ? Icons.sync_rounded
            : Icons.cloud_done_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Summary Strip ───────────────────────────────────────────────────────

  Widget _buildSummaryStrip(ProductivityProvider provider) {
    final slots = provider.slots;
    int focused = 0, distracted = 0;
    for (final s in slots) {
      if (s.type == ProductivityType.productive) {
        focused++;
      } else if (s.type == ProductivityType.wasted) {
        distracted++;
      }
    }
    final free = 72 - slots.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: SummaryPill(
              label: 'Focused',
              value: formatTime(focused * 20),
              color: AppColors.productive,
              icon: Icons.bolt_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SummaryPill(
              label: 'Distracted',
              value: formatTime(distracted * 20),
              color: AppColors.wasted,
              icon: Icons.warning_amber_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SummaryPill(
              label: 'Free',
              value: '$free slots',
              color: AppColors.primaryBlue,
              icon: Icons.schedule_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Toggle ──────────────────────────────────────────────────────────────

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(child: _toggleButton('Actual', _showActual, () {
              setState(() => _showActual = true);
            })),
            Expanded(child: _toggleButton('Planned', !_showActual, () {
              setState(() => _showActual = false);
            })),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active ? AppShadows.softShadow : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: active ? AppColors.primaryBlue : AppColors.textTertiary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Timeline ────────────────────────────────────────────────────────────

  Widget _buildTimeline(ProductivityProvider provider) {
    final blocks = _timeBlocks;
    final currentIdx = _currentBlockIndex;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final timeRange = blocks[index];
        final existingSlot = provider.slots
            .where((s) => s.timeRange == timeRange)
            .isNotEmpty
            ? provider.slots.firstWhere((s) => s.timeRange == timeRange)
            : null;

        final isCurrent = index == currentIdx;
        final isPast = index < currentIdx;
        final isMissed = isPast && existingSlot == null;
        final isSelected = _selectedRanges.contains(timeRange);

        return _TimeBlock(
          timeRange: timeRange,
          slot: existingSlot,
          isCurrent: isCurrent,
          isPast: isPast,
          isMissed: isMissed,
          isSelected: isSelected,
          isMultiSelectMode: _isMultiSelectMode,
          index: index,
          onTap: () {
            if (_isMultiSelectMode) {
              _onBlockTapInMultiSelect(timeRange);
            } else {
              _showQuickEntrySheet(context, timeRange);
            }
          },
          onLongPress: () => _onBlockLongPress(timeRange),
        );
      },
    );
  }

  // ─── Category Legend ─────────────────────────────────────────────────────

  Widget _buildCategoryLegend(ProductivityProvider provider) {
    final usedCategories = <String>{};
    for (final s in provider.slots) {
      usedCategories.add(s.category);
    }
    if (usedCategories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: usedCategories.map((cat) {
            final color = AppColors.categoryColor(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
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
                  Text(cat, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Multi-Select Bottom Action Bar ──────────────────────────────────────

  Widget _buildMultiSelectBar(ProductivityProvider provider) {
    final count = _selectedRanges.length;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Row(
          children: [
            // Cancel
            GestureDetector(
              onTap: _exitMultiSelect,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count slot${count == 1 ? '' : 's'} selected',
                    style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                  ),
                  Text(
                    '${count * 20} minutes total',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            // Assign button
            GestureDetector(
              onTap: () => _showBatchAssignSheet(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Assign Task',
                      style: AppTextStyles.bodyBold.copyWith(
                          color: Colors.white, fontSize: 13),
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

  // ─── Batch Assign Sheet ───────────────────────────────────────────────────

  void _showBatchAssignSheet(BuildContext context, ProductivityProvider provider) {
    final categories = provider.categories;
    String selectedCategory = categories.isNotEmpty ? categories.first : 'Other';
    ProductivityType selectedType = ProductivityType.productive;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedRanges.length} slots',
                      style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Assign to all', style: AppTextStyles.h3),
                ],
              ),
              const SizedBox(height: 20),
              Text('How was this time?',
                  style: AppTextStyles.label.copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _productivityButton('✨ Productive', AppColors.productive,
                      selectedType == ProductivityType.productive,
                      () => setModalState(() => selectedType = ProductivityType.productive)),
                  const SizedBox(width: 8),
                  _productivityButton('⚡ Neutral', AppColors.neutral,
                      selectedType == ProductivityType.neutral,
                      () => setModalState(() => selectedType = ProductivityType.neutral)),
                  const SizedBox(width: 8),
                  _productivityButton('💤 Wasted', AppColors.wasted,
                      selectedType == ProductivityType.wasted,
                      () => setModalState(() => selectedType = ProductivityType.wasted)),
                ],
              ),
              const SizedBox(height: 20),
              Text('Category',
                  style: AppTextStyles.label.copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: categories.map((cat) {
                  final color = AppColors.categoryColor(cat);
                  final isSelected = cat == selectedCategory;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(cat, style: AppTextStyles.caption.copyWith(
                            color: isSelected ? color : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 12,
                          )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Apply to ${_selectedRanges.length} slots',
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ranges = List<String>.from(_selectedRanges);
                  _exitMultiSelect();
                  await provider.addBatchTimeSlots(
                    timeRanges: ranges,
                    taskSelected: selectedCategory,
                    category: selectedCategory,
                    type: selectedType,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${ranges.length} slots assigned to $selectedCategory'),
                        backgroundColor: AppColors.primaryGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Quick Entry Sheet (single slot) ─────────────────────────────────────

  void _showQuickEntrySheet(BuildContext context, String timeRange) {
    final provider = context.read<ProductivityProvider>();
    final categories = provider.categories;

    final existingSlot = provider.slots
        .where((s) => s.timeRange == timeRange)
        .isNotEmpty
        ? provider.slots.firstWhere((s) => s.timeRange == timeRange)
        : null;

    String selectedCategory = existingSlot?.category ??
        (categories.isNotEmpty ? categories.first : 'Other');
    ProductivityType selectedType =
        existingSlot?.type ?? ProductivityType.productive;
    final bool isEditing = existingSlot != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(timeRange,
                        style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Text(isEditing ? 'Edit Block' : 'Log Activity',
                      style: AppTextStyles.h3),
                  const Spacer(),
                  if (isEditing && existingSlot.id != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        provider.deleteTimeSlot(existingSlot.id!);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.wasted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.wasted, size: 18),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('How was this time?',
                  style: AppTextStyles.label.copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _productivityButton(
                    '✨ Productive', AppColors.productive,
                    selectedType == ProductivityType.productive,
                    () => setModalState(
                        () => selectedType = ProductivityType.productive),
                  ),
                  const SizedBox(width: 8),
                  _productivityButton(
                    '⚡ Neutral', AppColors.neutral,
                    selectedType == ProductivityType.neutral,
                    () => setModalState(
                        () => selectedType = ProductivityType.neutral),
                  ),
                  const SizedBox(width: 8),
                  _productivityButton(
                    '💤 Wasted', AppColors.wasted,
                    selectedType == ProductivityType.wasted,
                    () => setModalState(
                        () => selectedType = ProductivityType.wasted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Category',
                  style: AppTextStyles.label.copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: categories.map((cat) {
                  final color = AppColors.categoryColor(cat);
                  final isSelected = cat == selectedCategory;
                  return GestureDetector(
                    onTap: () =>
                        setModalState(() => selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(cat,
                              style: AppTextStyles.caption.copyWith(
                                color: isSelected
                                    ? color
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: isEditing ? 'Update Block' : 'Save Block',
                onPressed: () async {
                  Navigator.pop(ctx); // Close sheet immediately — no wait
                  try {
                    if (isEditing) {
                      final typeName = selectedType.name;
                      final capitalizedType =
                          typeName[0].toUpperCase() + typeName.substring(1);
                      // Runs optimistically — no reload
                      await provider.updateTimeSlot(
                        existingSlot.id!,
                        taskSelected: selectedCategory,
                        category: selectedCategory,
                        productivityType: capitalizedType,
                      );
                    } else {
                      final now = DateTime.now();
                      final cleanDate =
                          DateTime(now.year, now.month, now.day, 12, 0, 0);
                      await provider.addTimeSlot(TimeSlot(
                        date: cleanDate.toIso8601String(),
                        timeRange: timeRange,
                        taskSelected: selectedCategory,
                        category: selectedCategory,
                        type: selectedType,
                      ));
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '$timeRange ${isEditing ? "updated" : "logged"} as ${selectedType.name}'),
                          backgroundColor: AppColors.primaryGreen,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed: ${e.toString().replaceAll("Exception: ", "")}'),
                          backgroundColor: AppColors.wasted,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productivityButton(
      String label, Color color, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                )),
          ),
        ),
      ),
    );
  }
}

// ─── Individual Time Block Widget ─────────────────────────────────────────────

class _TimeBlock extends StatelessWidget {
  final String timeRange;
  final TimeSlot? slot;
  final bool isCurrent;
  final bool isPast;
  final bool isMissed;
  final bool isSelected;
  final bool isMultiSelectMode;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TimeBlock({
    required this.timeRange,
    this.slot,
    required this.isCurrent,
    required this.isPast,
    required this.isMissed,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = timeRange.split('-')[0];
    final isLogged = slot != null;
    final catColor =
        isLogged ? AppColors.categoryColor(slot!.category) : AppColors.border;

    Color bgColor;
    if (isSelected) {
      bgColor = AppColors.primaryBlue.withValues(alpha: 0.08);
    } else if (isCurrent) {
      bgColor = AppColors.primaryBlue.withValues(alpha: 0.04);
    } else if (isLogged) {
      bgColor = catColor.withValues(alpha: 0.04);
    } else {
      bgColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  startTime,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : isCurrent
                            ? AppColors.primaryBlue
                            : isPast
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                  ),
                ),
              ),
              // Color indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 4,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : isCurrent
                          ? AppColors.primaryBlue
                          : isLogged
                              ? _typeColor(slot!.type)
                              : isMissed
                                  ? AppColors.border
                                  : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: AppColors.primaryBlue.withValues(alpha: 0.5),
                            width: 1.5)
                        : isCurrent
                            ? Border.all(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.3),
                                width: 1.5)
                            : isLogged
                                ? Border.all(
                                    color: catColor.withValues(alpha: 0.15))
                                : null,
                  ),
                  child: Row(
                    children: [
                      if (isLogged) ...[
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          slot!.category,
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 13,
                            color: isPast && !isCurrent
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primaryBlue, size: 18)
                        else
                          _typeBadge(slot!.type),
                      ] else ...[
                        Text(
                          _emptyLabel,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: isCurrent
                                ? AppColors.primaryBlue
                                : AppColors.textHint,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primaryBlue, size: 18)
                        else
                          Icon(
                            isMultiSelectMode
                                ? Icons.radio_button_unchecked_rounded
                                : isCurrent
                                    ? Icons.add_circle_outline_rounded
                                    : Icons.circle_outlined,
                            size: 16,
                            color: isCurrent
                                ? AppColors.primaryBlue
                                : AppColors.textHint,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _emptyLabel {
    if (isCurrent) return 'Now — Tap to log';
    if (isMissed) return 'Untracked';
    return isMultiSelectMode ? 'Tap to select' : 'Available';
  }

  Widget _typeBadge(ProductivityType type) {
    final emoji = type == ProductivityType.productive
        ? '✨'
        : type == ProductivityType.neutral
            ? '⚡'
            : '💤';
    return Text(emoji, style: const TextStyle(fontSize: 14));
  }

  Color _typeColor(ProductivityType type) {
    switch (type) {
      case ProductivityType.productive:
        return AppColors.productive;
      case ProductivityType.neutral:
        return AppColors.neutral;
      case ProductivityType.wasted:
        return AppColors.wasted;
    }
  }
}
