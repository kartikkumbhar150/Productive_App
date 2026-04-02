import { Request, Response } from 'express';
import TimeSlot, { ProductivityType } from '../models/TimeSlot';
import Task from '../models/Task';
import { generateDailyInsights } from '../services/groqService';
import { getCache, setCache } from '../services/redisService';

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

// Compute Productivity Index (0-100)
// Formula: (taskCompletionRate * 40) + (timeUtilization * 30) + (consistency * 30)
const computeProductivityIndex = (
  completedTasks: number,
  totalTasks: number,
  productiveMinutes: number,
  totalMinutes: number,
  daysTracked: number,
  totalDays: number
): number => {
  const taskRate = totalTasks > 0 ? (completedTasks / totalTasks) : 0;
  const timeUtil = totalMinutes > 0 ? (productiveMinutes / totalMinutes) : 0;
  const consistency = totalDays > 0 ? Math.min(daysTracked / totalDays, 1) : 0;
  return Math.round((taskRate * 40) + (timeUtil * 30) + (consistency * 30));
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
    
    // Cache Key format: user:{userId}:analytics:{period}:{startDate}
    const dateKey = start.toISOString().split('T')[0];
    const cacheKey = `user:${user._id}:analytics:${period}:${dateKey}`;
    
    const cachedData = await getCache(cacheKey);
    if (cachedData) return res.json(cachedData);

    const slots = await TimeSlot.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    // Fetch tasks for productivity index
    const tasks = await Task.find({
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
        productivityIndex: 0,
        categoryBreakdown: {},
        taskBreakdown: {},
        productivityByCategory: {},
        totalTasks: tasks.length,
        completedTasks: tasks.filter(t => t.isCompleted).length,
        insights: 'No time tracked for this period.',
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
    let daysTrackedSet = new Set<string>();

    slots.forEach((slot) => {
      if (slot.productivityType === ProductivityType.PRODUCTIVE) productiveCount++;
      else if (slot.productivityType === ProductivityType.WASTED) wastedCount++;
      else neutralCount++;

      categoryMap[slot.category] = (categoryMap[slot.category] || 0) + 20;

      const taskName = (slot.taskSelected as string) || slot.category;
      taskMap[taskName] = (taskMap[taskName] || 0) + 20;

      if (!categoryProductivity[slot.category]) {
        categoryProductivity[slot.category] = { productive: 0, neutral: 0, wasted: 0 };
      }
      if (slot.productivityType === ProductivityType.PRODUCTIVE) {
        categoryProductivity[slot.category].productive += 20;
      } else if (slot.productivityType === ProductivityType.WASTED) {
        categoryProductivity[slot.category].wasted += 20;
      } else {
        categoryProductivity[slot.category].neutral += 20;
      }

      daysTrackedSet.add(new Date(slot.date).toISOString().split('T')[0]);
    });

    const productiveMinutes = productiveCount * 20;
    const wastedMinutes = wastedCount * 20;
    const neutralMinutes = neutralCount * 20;
    const totalMinutes = totalTrackedSlots * 20;
    const productivityPercentage = (productiveMinutes / totalMinutes) * 100;

    const totalDays = period === 'day' ? 1 : 7;
    const completedTasks = tasks.filter(t => t.isCompleted).length;
    const productivityIndex = computeProductivityIndex(
      completedTasks, tasks.length,
      productiveMinutes, totalMinutes,
      daysTrackedSet.size, totalDays
    );

    let insights = 'Set GROQ_API_KEY in .env for AI insights.';
    try {
      insights = await generateDailyInsights({
        slotsCompleted: totalTrackedSlots,
        productiveMinutes, wastedMinutes, neutralMinutes,
        productivityPercentage, categories: categoryMap, tasks: taskMap,
      });
    } catch (e) {
      console.error('Groq insights error:', e);
    }

    const responseData = {
      totalMinutes,
      productiveMinutes,
      wastedMinutes,
      neutralMinutes,
      productivityPercentage: parseFloat(productivityPercentage.toFixed(2)),
      productivityIndex,
      categoryBreakdown: categoryMap,
      taskBreakdown: taskMap,
      productivityByCategory: categoryProductivity,
      totalTasks: tasks.length,
      completedTasks,
      insights,
    };

    await setCache(cacheKey, responseData, 3600); // Cache for 1 hour
    res.json(responseData);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    Get 7-day weekly trend data
// @route   GET /api/analytics/weekly-trend
export const getWeeklyTrend = async (req: Request, res: Response) => {
  const { date } = req.query;
  const user = (req as any).user;

  try {
    const baseDate = new Date((date as string) || new Date().toISOString());
    const end = new Date(baseDate);
    end.setHours(23, 59, 59, 999);
    const start = new Date(baseDate);
    start.setDate(start.getDate() - 6);
    start.setHours(0, 0, 0, 0);

    const dateKey = end.toISOString().split('T')[0];
    const cacheKey = `user:${user._id}:weekly-trend:${dateKey}`;

    const cachedData = await getCache(cacheKey);
    if (cachedData) return res.json(cachedData);

    const slots = await TimeSlot.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    const tasks = await Task.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    // Build day map
    const dayMap: { [key: string]: { productive: number; neutral: number; wasted: number; total: number } } = {};
    const taskDayMap: { [key: string]: { completed: number; total: number } } = {};

    // Initialize all 7 days
    for (let i = 0; i < 7; i++) {
      const d = new Date(start);
      d.setDate(d.getDate() + i);
      const key = d.toISOString().split('T')[0];
      dayMap[key] = { productive: 0, neutral: 0, wasted: 0, total: 0 };
      taskDayMap[key] = { completed: 0, total: 0 };
    }

    slots.forEach(slot => {
      const key = new Date(slot.date).toISOString().split('T')[0];
      if (dayMap[key]) {
        dayMap[key].total += 20;
        if (slot.productivityType === ProductivityType.PRODUCTIVE) dayMap[key].productive += 20;
        else if (slot.productivityType === ProductivityType.WASTED) dayMap[key].wasted += 20;
        else dayMap[key].neutral += 20;
      }
    });

    tasks.forEach(task => {
      const key = new Date(task.date).toISOString().split('T')[0];
      if (taskDayMap[key]) {
        taskDayMap[key].total++;
        if (task.isCompleted) taskDayMap[key].completed++;
      }
    });

    const trend = Object.entries(dayMap)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, data]) => {
        const taskData = taskDayMap[date] || { completed: 0, total: 0 };
        const prodIndex = computeProductivityIndex(
          taskData.completed, taskData.total,
          data.productive, data.total,
          data.total > 0 ? 1 : 0, 1
        );
        return {
          date,
          productiveMin: data.productive,
          wastedMin: data.wasted,
          neutralMin: data.neutral,
          totalMin: data.total,
          tasksCompleted: taskData.completed,
          tasksMissed: taskData.total - taskData.completed,
          productivityIndex: prodIndex,
        };
      });

    // Cumulative focus time
    let cumulative = 0;
    const cumulativeFocus = trend.map(day => {
      cumulative += day.productiveMin;
      return { date: day.date, cumulativeMinutes: cumulative };
    });

    const responseData = { trend, cumulativeFocus };
    await setCache(cacheKey, responseData, 3600); // Cache for 1 hour
    
    res.json(responseData);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    Get heatmap data for a month (slot-level fill for GitHub-style grid)
// @route   GET /api/analytics/heatmap
export const getHeatmapData = async (req: Request, res: Response) => {
  const { month, year } = req.query;
  const user = (req as any).user;

  try {
    const m = parseInt(month as string) || new Date().getMonth() + 1;
    const y = parseInt(year as string) || new Date().getFullYear();

    const cacheKey = `user:${user._id}:heatmap:${y}-${m.toString().padStart(2, '0')}`;
    const cachedData = await getCache(cacheKey);
    if (cachedData) return res.json(cachedData);

    const start = new Date(y, m - 1, 1);
    start.setHours(0, 0, 0, 0);
    const end = new Date(y, m, 0);
    end.setHours(23, 59, 59, 999);

    const slots = await TimeSlot.find({
      userId: user._id,
      date: { $gte: start, $lte: end },
    });

    // Build day → totalMinutes map
    const dayMap: { [key: string]: number } = {};
    const daysInMonth = end.getDate();
    for (let d = 1; d <= daysInMonth; d++) {
      const key = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      dayMap[key] = 0;
    }

    slots.forEach(slot => {
      const key = new Date(slot.date).toISOString().split('T')[0];
      if (dayMap[key] !== undefined) {
        dayMap[key] += 20;
      }
    });

    // Also build hourly heatmap (hour × day grid)
    const hourlyMap: { [key: string]: { [hour: number]: number } } = {};
    slots.forEach(slot => {
      const dateKey = new Date(slot.date).toISOString().split('T')[0];
      const hourMatch = slot.timeRange.match(/^(\d{2}):/);
      if (hourMatch) {
        const hour = parseInt(hourMatch[1]);
        if (!hourlyMap[dateKey]) hourlyMap[dateKey] = {};
        hourlyMap[dateKey][hour] = (hourlyMap[dateKey][hour] || 0) + 20;
      }
    });

    const maxMinutes = Math.max(...Object.values(dayMap), 1);

    const responseData = {
      month: m,
      year: y,
      daysInMonth,
      dailyMinutes: dayMap,
      maxMinutes,
      hourlyMap,
      firstDayOfWeek: new Date(y, m - 1, 1).getDay(), // 0=Sun
    };

    await setCache(cacheKey, responseData, 3600); // Cache for 1 hour
    res.json(responseData);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};
