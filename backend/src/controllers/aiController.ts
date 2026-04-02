import { Request, Response } from 'express';
import { getCache, setCache } from '../services/redisService';
import TimeSlot, { ProductivityType } from '../models/TimeSlot';
import Task from '../models/Task';

// @desc    Get AI-powered insights based on last 7 days of data
// @route   GET /api/ai/insights
export const getAIInsights = async (req: Request, res: Response) => {
  const user = (req as any).user;

  try {
    const cacheKey = `user:${user._id}:ai-insights`;
    const cachedData = await getCache(cacheKey);
    if (cachedData) return res.json(cachedData);

    const end = new Date();
    end.setHours(23, 59, 59, 999);
    const start = new Date();
    start.setDate(start.getDate() - 6);
    start.setHours(0, 0, 0, 0);

    const slots = await TimeSlot.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    const tasks = await Task.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    if (slots.length === 0) {
      return res.json({
        insights: [
          { type: 'info', icon: '📊', text: 'Start tracking your time to get personalized insights!' },
          { type: 'tip', icon: '💡', text: 'Try logging at least 5 time blocks per day for best results.' },
        ],
        bestHours: [],
        worstHours: [],
        summary: 'No data available yet. Start tracking to see patterns!',
      });
    }

    // Analyze hourly patterns
    const hourlyData: { [hour: number]: { productive: number; total: number } } = {};
    for (let h = 0; h < 24; h++) {
      hourlyData[h] = { productive: 0, total: 0 };
    }

    const dailySlotCounts: { [key: string]: number } = {};

    slots.forEach(slot => {
      const hourMatch = slot.timeRange.match(/^(\d{2}):/);
      if (hourMatch) {
        const hour = parseInt(hourMatch[1]);
        hourlyData[hour].total++;
        if (slot.productivityType === ProductivityType.PRODUCTIVE) {
          hourlyData[hour].productive++;
        }
      }
      const dateKey = new Date(slot.date).toISOString().split('T')[0];
      dailySlotCounts[dateKey] = (dailySlotCounts[dateKey] || 0) + 1;
    });

    // Find best and worst hours
    const hourlyRanked = Object.entries(hourlyData)
      .filter(([_, data]) => data.total >= 2) // At least 2 slots at this hour across the week
      .map(([hour, data]) => ({
        hour: parseInt(hour),
        rate: data.total > 0 ? (data.productive / data.total) * 100 : 0,
        total: data.total,
      }))
      .sort((a, b) => b.rate - a.rate);

    const bestHours = hourlyRanked.slice(0, 3).map(h => ({
      hour: h.hour,
      label: `${String(h.hour).padStart(2, '0')}:00`,
      productivityRate: Math.round(h.rate),
    }));

    const worstHours = hourlyRanked.slice(-3).reverse().map(h => ({
      hour: h.hour,
      label: `${String(h.hour).padStart(2, '0')}:00`,
      productivityRate: Math.round(h.rate),
    }));

    // Calculate stats
    const totalSlots = slots.length;
    const productiveSlots = slots.filter(s => s.productivityType === ProductivityType.PRODUCTIVE).length;
    const wastedSlots = slots.filter(s => s.productivityType === ProductivityType.WASTED).length;
    const completedTasks = tasks.filter(t => t.isCompleted).length;
    const taskCompletionRate = tasks.length > 0 ? Math.round((completedTasks / tasks.length) * 100) : 0;
    const productivityRate = totalSlots > 0 ? Math.round((productiveSlots / totalSlots) * 100) : 0;

    // Generate insights
    const insights: { type: string; icon: string; text: string }[] = [];

    // Best productive hours insight
    if (bestHours.length > 0) {
      const bestLabels = bestHours.map(h => h.label).join(', ');
      insights.push({
        type: 'pattern',
        icon: '🎯',
        text: `You're most productive around ${bestLabels}. Schedule important tasks during these hours.`,
      });
    }

    // Worst hours insight
    if (worstHours.length > 0 && worstHours[0].productivityRate < 40) {
      const worstLabels = worstHours.map(h => h.label).join(', ');
      insights.push({
        type: 'warning',
        icon: '⚠️',
        text: `Productivity drops around ${worstLabels}. Consider taking breaks or switching activities.`,
      });
    }

    // Task completion insight
    if (taskCompletionRate < 50 && tasks.length > 0) {
      insights.push({
        type: 'improvement',
        icon: '📋',
        text: `Only ${taskCompletionRate}% tasks completed this week. Try breaking large tasks into smaller ones.`,
      });
    } else if (taskCompletionRate >= 80) {
      insights.push({
        type: 'achievement',
        icon: '🏆',
        text: `Great job! ${taskCompletionRate}% task completion rate. Keep up the momentum!`,
      });
    }

    // Wasted time insight
    const wastedRate = totalSlots > 0 ? Math.round((wastedSlots / totalSlots) * 100) : 0;
    if (wastedRate > 30) {
      insights.push({
        type: 'warning',
        icon: '💤',
        text: `${wastedRate}% of tracked time was unproductive. Identify your biggest distractions.`,
      });
    }

    // Consistency insight
    const daysTracked = Object.keys(dailySlotCounts).length;
    if (daysTracked < 5) {
      insights.push({
        type: 'tip',
        icon: '📅',
        text: `You only tracked ${daysTracked}/7 days. Consistency is key to building productive habits.`,
      });
    }

    // Average slots per day
    const avgSlotsPerDay = Math.round(totalSlots / Math.max(daysTracked, 1));
    if (avgSlotsPerDay < 10) {
      insights.push({
        type: 'tip',
        icon: '⏱️',
        text: `Averaging ${avgSlotsPerDay} blocks/day (${avgSlotsPerDay * 20}min). Try tracking more to get a complete picture.`,
      });
    }

    const summary = `This week: ${productivityRate}% productive across ${totalSlots} time blocks. ${completedTasks}/${tasks.length} tasks completed.`;

    const payload = {
      insights: insights.slice(0, 5), // Max 5 insights
      bestHours,
      worstHours,
      summary,
      stats: {
        totalSlots,
        productiveSlots,
        wastedSlots,
        neutralSlots: totalSlots - productiveSlots - wastedSlots,
        productivityRate,
        taskCompletionRate,
        daysTracked,
        avgSlotsPerDay,
      },
    };

    await setCache(cacheKey, payload, 3600);
    res.json(payload);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};
