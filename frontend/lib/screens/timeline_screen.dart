import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../models/time_slot.dart';
import '../providers/productivity_provider.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late ScrollController _scrollController;
  final double _itemHeight = 72.0; // approximate height per block

  List<String> _generateTimeBlocks() {
    List<String> blocks = [];
    DateTime start = DateTime(2020, 1, 1, 0, 0);
    for (int i = 0; i < 72; i++) {
      String from = DateFormat('HH:mm').format(start);
      start = start.add(const Duration(minutes: 20));
      String to = DateFormat('HH:mm').format(start);
      blocks.add('$from-$to');
    }
    return blocks;
  }

  int _getCurrentBlockIndex() {
    final now = DateTime.now();
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    return (minutesSinceMidnight / 20).floor().clamp(0, 71);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Auto-scroll to current time block after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentIndex = _getCurrentBlockIndex();
      // Scroll so current block is near the top (show 1-2 past blocks above)
      final targetOffset = ((currentIndex - 2).clamp(0, 71)) * _itemHeight;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _generateTimeBlocks();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Time Blocks', style: AppTextStyles.h1),
                      const SizedBox(height: 4),
                      Text(
                        '72 slots • 20 min each • Tap to log',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  // Jump to now button
                  GestureDetector(
                    onTap: () {
                      final currentIndex = _getCurrentBlockIndex();
                      final targetOffset =
                          ((currentIndex - 2).clamp(0, 71)) * _itemHeight;
                      _scrollController.animateTo(
                        targetOffset,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppShadows.buttonShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Now',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Timeline List
            Expanded(
              child: Consumer<ProductivityProvider>(
                builder: (context, provider, _) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: blocks.length,
                    itemBuilder: (context, index) {
                      return _buildTimeBlock(
                          context, blocks[index], index, provider.slots);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlock(BuildContext context, String timeRange, int index,
      List<TimeSlot> slots) {
    final now = DateTime.now();
    final hour = int.parse(timeRange.substring(0, 2));
    final minute = int.parse(timeRange.substring(3, 5));
    final blockStartMinutes = hour * 60 + minute;
    final nowMinutes = now.hour * 60 + now.minute;

    final isCurrentBlock =
        nowMinutes >= blockStartMinutes && nowMinutes < blockStartMinutes + 20;
    final isPastBlock = nowMinutes >= blockStartMinutes + 20;

    // Check if this block has been logged
    final existingSlot = slots.where((s) => s.timeRange == timeRange).isNotEmpty
        ? slots.firstWhere((s) => s.timeRange == timeRange)
        : null;

    // Determine colors and labels
    Color blockColor;
    Color textColor;
    Color timeTextColor;
    String statusLabel;
    IconData statusIcon;
    double opacity;

    if (existingSlot != null) {
      opacity = isPastBlock ? 0.6 : 1.0;
      switch (existingSlot.type) {
        case ProductivityType.productive:
          blockColor = AppColors.primaryGreen.withOpacity(isPastBlock ? 0.05 : 0.08);
          textColor = AppColors.primaryGreen.withOpacity(opacity);
          timeTextColor = AppColors.primaryGreen.withOpacity(opacity);
          statusLabel = '✨ Productive';
          statusIcon = Icons.check_circle_rounded;
          break;
        case ProductivityType.neutral:
          blockColor = AppColors.softOrange.withOpacity(isPastBlock ? 0.05 : 0.08);
          textColor = AppColors.softOrange.withOpacity(opacity);
          timeTextColor = AppColors.softOrange.withOpacity(opacity);
          statusLabel = '⚡ Neutral';
          statusIcon = Icons.remove_circle_rounded;
          break;
        case ProductivityType.wasted:
          blockColor = AppColors.softPink.withOpacity(isPastBlock ? 0.05 : 0.08);
          textColor = AppColors.softPink.withOpacity(opacity);
          timeTextColor = AppColors.softPink.withOpacity(opacity);
          statusLabel = '💤 Wasted';
          statusIcon = Icons.cancel_rounded;
          break;
      }
    } else if (isCurrentBlock) {
      blockColor = AppColors.primaryBlue.withOpacity(0.08);
      textColor = AppColors.primaryBlue;
      timeTextColor = AppColors.primaryBlue;
      statusLabel = '● NOW';
      statusIcon = Icons.access_time_filled_rounded;
      opacity = 1.0;
    } else if (isPastBlock) {
      // Past unlogged blocks = dark/muted
      blockColor = const Color(0xFFF0F0F4);
      textColor = AppColors.textHint;
      timeTextColor = AppColors.textHint;
      statusLabel = 'Missed';
      statusIcon = Icons.remove_rounded;
      opacity = 0.5;
    } else {
      // Future blocks
      blockColor = AppColors.surface;
      textColor = AppColors.textTertiary;
      timeTextColor = AppColors.textPrimary;
      statusLabel = 'Log';
      statusIcon = Icons.add_rounded;
      opacity = 1.0;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _showQuickEntrySheet(context, timeRange),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrentBlock
                  ? AppColors.primaryBlue.withOpacity(0.4)
                  : existingSlot != null
                      ? textColor.withOpacity(0.2)
                      : isPastBlock
                          ? AppColors.border.withOpacity(0.3)
                          : AppColors.border.withOpacity(0.5),
              width: isCurrentBlock ? 2 : 1,
            ),
            boxShadow: isCurrentBlock
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : AppShadows.softShadow,
          ),
          child: Row(
            children: [
              // Time indicator bar
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrentBlock
                      ? AppColors.primaryBlue
                      : existingSlot != null
                          ? textColor
                          : isPastBlock
                              ? AppColors.border.withOpacity(0.4)
                              : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Time range text
              SizedBox(
                width: 95,
                child: Text(
                  timeRange,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: timeTextColor,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: isCurrentBlock ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              // Category label for logged slots
              if (existingSlot != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    existingSlot.category,
                    style: AppTextStyles.caption.copyWith(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCurrentBlock
                      ? AppColors.primaryBlue.withOpacity(0.12)
                      : existingSlot != null
                          ? textColor.withOpacity(0.1)
                          : isPastBlock
                              ? Colors.transparent
                              : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: textColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickEntrySheet(BuildContext context, String timeRange) {
    final provider = context.read<ProductivityProvider>();
    final categories = provider.categories;

    // Check if slot already exists for this timeRange
    final existingSlot = provider.slots
        .where((s) => s.timeRange == timeRange)
        .isNotEmpty
        ? provider.slots.firstWhere((s) => s.timeRange == timeRange)
        : null;

    // Pre-fill with existing data or defaults
    String selectedCategory = existingSlot != null
        ? existingSlot.category
        : (categories.isNotEmpty ? categories.first : 'Other');
    ProductivityType selectedType =
        existingSlot?.type ?? ProductivityType.productive;
    final bool isEditing = existingSlot != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: isEditing
                          ? AppColors.warmGradient
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                        isEditing
                            ? Icons.edit_rounded
                            : Icons.schedule_rounded,
                        color: Colors.white,
                        size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            isEditing
                                ? 'Edit $timeRange'
                                : 'Log $timeRange',
                            style: AppTextStyles.h3),
                        Text(
                            isEditing
                                ? 'Update or delete this entry'
                                : 'Quick entry • 20 min block',
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  // Delete button for existing slots
                  if (isEditing)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        provider.deleteTimeSlot(existingSlot!.id!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$timeRange entry deleted'),
                            backgroundColor: AppColors.softPink,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.softPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.softPink, size: 20),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('HOW WAS THIS TIME?',
                  style: AppTextStyles.label.copyWith(letterSpacing: 1)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ProductivityChip(
                      label: '✨ Productive',
                      color: AppColors.primaryGreen,
                      selected:
                          selectedType == ProductivityType.productive,
                      onTap: () => setSheetState(() =>
                          selectedType = ProductivityType.productive),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ProductivityChip(
                      label: '⚡ Neutral',
                      color: AppColors.softOrange,
                      selected:
                          selectedType == ProductivityType.neutral,
                      onTap: () => setSheetState(
                          () => selectedType = ProductivityType.neutral),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ProductivityChip(
                      label: '💤 Wasted',
                      color: AppColors.softPink,
                      selected:
                          selectedType == ProductivityType.wasted,
                      onTap: () => setSheetState(
                          () => selectedType = ProductivityType.wasted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('CATEGORY / TASK',
                  style: AppTextStyles.label.copyWith(letterSpacing: 1)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.isEmpty
                    ? [
                        Text('No categories — add in Settings',
                            style: AppTextStyles.caption)
                      ]
                    : categories.map((cat) {
                        final isSelected = cat == selectedCategory;
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue.withOpacity(0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: AppTextStyles.caption.copyWith(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
              ),
              const SizedBox(height: 28),
              GradientButton(
                text: isEditing ? 'Update Time Block' : 'Save Time Block',
                onPressed: () {
                  if (isEditing && existingSlot!.id != null) {
                    final typeName = selectedType.name;
                    final capitalizedType = typeName[0].toUpperCase() + typeName.substring(1);
                    provider.updateTimeSlot(
                      existingSlot!.id!,
                      taskSelected: selectedCategory,
                      category: selectedCategory,
                      productivityType: capitalizedType,
                    );
                  } else {
                    provider.addTimeSlot(TimeSlot(
                      date: DateTime.now().toIso8601String(),
                      timeRange: timeRange,
                      taskSelected: selectedCategory,
                      category: selectedCategory,
                      type: selectedType,
                    ));
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '$timeRange ${isEditing ? "updated" : "logged"} as ${selectedType.name}'),
                      backgroundColor: AppColors.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

