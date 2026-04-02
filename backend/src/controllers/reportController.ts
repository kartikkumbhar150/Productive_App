import { Request, Response } from 'express';
import TimeSlot, { ProductivityType } from '../models/TimeSlot';
import Task from '../models/Task';

// @desc    Get report for a custom date range
// @route   GET /api/reports?startDate=...&endDate=...
export const getReport = async (req: Request, res: Response) => {
  const { startDate, endDate } = req.query;
  const user = (req as any).user;

  if (!startDate || !endDate) {
    return res.status(400).json({ message: 'startDate and endDate are required' });
  }

  try {
    const start = new Date(startDate as string);
    start.setHours(0, 0, 0, 0);
    const end = new Date(endDate as string);
    end.setHours(23, 59, 59, 999);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({ message: 'Invalid date format' });
    }

    if (start > end) {
      return res.status(400).json({ message: 'startDate must be before endDate' });
    }

    // Fetch all time slots in range
    const slots = await TimeSlot.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    // Fetch all tasks in range
    const tasks = await Task.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    const totalTrackedSlots = slots.length;

    if (totalTrackedSlots === 0) {
      return res.json({
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        totalDays: Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)),
        totalMinutes: 0,
        productiveMinutes: 0,
        wastedMinutes: 0,
        neutralMinutes: 0,
        productivityPercentage: 0,
        categoryBreakdown: {},
        taskBreakdown: {},
        productivityByCategory: {},
        totalTasks: tasks.length,
        completedTasks: tasks.filter(t => t.isCompleted).length,
        dailyBreakdown: [],
      });
    }

    let productiveCount = 0;
    let wastedCount = 0;
    let neutralCount = 0;
    let categoryMap: { [key: string]: number } = {};
    let taskMap: { [key: string]: number } = {};
    let categoryProductivity: {
      [key: string]: { productive: number; neutral: number; wasted: number };
    } = {};

    // Daily breakdown map
    let dailyMap: {
      [key: string]: {
        productive: number;
        wasted: number;
        neutral: number;
        total: number;
      };
    } = {};

    slots.forEach((slot) => {
      // Each slot is 20 minutes
      if (slot.productivityType === ProductivityType.PRODUCTIVE) productiveCount++;
      else if (slot.productivityType === ProductivityType.WASTED) wastedCount++;
      else neutralCount++;

      // Category breakdown (minutes)
      categoryMap[slot.category] = (categoryMap[slot.category] || 0) + 20;

      // Task breakdown (minutes)
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

      // Daily breakdown
      const dateKey = new Date(slot.date).toISOString().split('T')[0];
      if (!dailyMap[dateKey]) {
        dailyMap[dateKey] = { productive: 0, wasted: 0, neutral: 0, total: 0 };
      }
      dailyMap[dateKey].total += 20;
      if (slot.productivityType === ProductivityType.PRODUCTIVE) {
        dailyMap[dateKey].productive += 20;
      } else if (slot.productivityType === ProductivityType.WASTED) {
        dailyMap[dateKey].wasted += 20;
      } else {
        dailyMap[dateKey].neutral += 20;
      }
    });

    const productiveMinutes = productiveCount * 20;
    const wastedMinutes = wastedCount * 20;
    const neutralMinutes = neutralCount * 20;
    const totalMinutes = totalTrackedSlots * 20;
    const productivityPercentage = (productiveMinutes / totalMinutes) * 100;

    // Convert dailyMap to sorted array
    const dailyBreakdown = Object.entries(dailyMap)
      .map(([date, data]) => ({
        date,
        ...data,
        productivityPercentage: data.total > 0
          ? parseFloat(((data.productive / data.total) * 100).toFixed(2))
          : 0,
      }))
      .sort((a, b) => a.date.localeCompare(b.date));

    const totalDays = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;

    res.json({
      startDate: start.toISOString(),
      endDate: end.toISOString(),
      totalDays,
      totalMinutes,
      productiveMinutes,
      wastedMinutes,
      neutralMinutes,
      productivityPercentage: parseFloat(productivityPercentage.toFixed(2)),
      categoryBreakdown: categoryMap,
      taskBreakdown: taskMap,
      productivityByCategory: categoryProductivity,
      totalTasks: tasks.length,
      completedTasks: tasks.filter(t => t.isCompleted).length,
      dailyBreakdown,
    });
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};
