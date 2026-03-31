import { Request, Response } from 'express';
import TimeSlot, { ProductivityType } from '../models/TimeSlot';
import { generateDailyInsights } from '../services/groqService';

const getDateRange = (dateStr: string, period: string) => {
  const queryDate = new Date(dateStr);
  const start = new Date(queryDate);
  const end = new Date(queryDate);

  if (period === 'day') {
    start.setHours(0, 0, 0, 0);
    end.setHours(23, 59, 59, 999);
  } else if (period === 'week') {
    const dayOfWeek = start.getDay();
    start.setDate(start.getDate() - dayOfWeek);
    start.setHours(0, 0, 0, 0);
    end.setDate(end.getDate() + (6 - dayOfWeek));
    end.setHours(23, 59, 59, 999);
  }
  return { start, end };
};

// @desc    Get analytics for a given period
// @route   GET /api/analytics/:period
export const getAnalytics = async (req: Request, res: Response) => {
  const { period } = req.params;
  const { date } = req.query;
  const user = (req as any).user;

  try {
    const { start, end } = getDateRange(
      (date as string) || new Date().toISOString(),
      period
    );

    const slots = await TimeSlot.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    const totalTrackedSlots = slots.length;
    if (totalTrackedSlots === 0) {
      return res.json({
        totalMinutes: 0,
        productiveMinutes: 0,
        wastedMinutes: 0,
        neutralMinutes: 0,
        productivityPercentage: 0,
        categoryBreakdown: {},
        taskBreakdown: {},
        productivityByCategory: {},
        insights: 'No time tracked for this period.',
      });
    }

    let productiveCount = 0;
    let wastedCount = 0;
    let neutralCount = 0;
    let categoryMap: { [key: string]: number } = {};
    let taskMap: { [key: string]: number } = {};
    // Track productivity type per category
    let categoryProductivity: {
      [key: string]: { productive: number; neutral: number; wasted: number };
    } = {};

    slots.forEach((slot) => {
      // Each slot is 20 minutes
      if (slot.productivityType === ProductivityType.PRODUCTIVE) productiveCount++;
      else if (slot.productivityType === ProductivityType.WASTED) wastedCount++;
      else neutralCount++;

      // Category breakdown (minutes)
      categoryMap[slot.category] = (categoryMap[slot.category] || 0) + 20;

      // Task breakdown (minutes) — use taskSelected field
      const taskName = (slot.taskSelected as string) || slot.category;
      taskMap[taskName] = (taskMap[taskName] || 0) + 20;

      // Productivity per category
      if (!categoryProductivity[slot.category]) {
        categoryProductivity[slot.category] = {
          productive: 0,
          neutral: 0,
          wasted: 0,
        };
      }
      if (slot.productivityType === ProductivityType.PRODUCTIVE) {
        categoryProductivity[slot.category].productive += 20;
      } else if (slot.productivityType === ProductivityType.WASTED) {
        categoryProductivity[slot.category].wasted += 20;
      } else {
        categoryProductivity[slot.category].neutral += 20;
      }
    });

    const productiveMinutes = productiveCount * 20;
    const wastedMinutes = wastedCount * 20;
    const neutralMinutes = neutralCount * 20;
    const totalMinutes = totalTrackedSlots * 20;
    const productivityPercentage = (productiveMinutes / totalMinutes) * 100;

    // Get insights via LLM
    const promptPayload = {
      slotsCompleted: totalTrackedSlots,
      productiveMinutes,
      wastedMinutes,
      neutralMinutes,
      productivityPercentage,
      categories: categoryMap,
      tasks: taskMap,
    };

    let insights = 'Set GROQ_API_KEY in .env for AI insights.';
    try {
      insights = await generateDailyInsights(promptPayload);
    } catch (e) {
      console.error('Groq insights error:', e);
    }

    res.json({
      totalMinutes,
      productiveMinutes,
      wastedMinutes,
      neutralMinutes,
      productivityPercentage: productivityPercentage.toFixed(2),
      categoryBreakdown: categoryMap,
      taskBreakdown: taskMap,
      productivityByCategory: categoryProductivity,
      insights,
    });
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};
