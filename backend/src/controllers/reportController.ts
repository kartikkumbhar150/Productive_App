import { Request, Response } from 'express';
import TimeSlot, { ProductivityType } from '../models/TimeSlot';
import Task from '../models/Task';
import { getCache, setCache } from '../services/redisService';

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

    const dateKeyStart = start.toISOString().split('T')[0];
    const dateKeyEnd = end.toISOString().split('T')[0];
    const cacheKey = `user:${user._id}:reports:${dateKeyStart}-${dateKeyEnd}`;

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
        productivityIndex: 0,
        categoryBreakdown: {},
        taskBreakdown: {},
        productivityByCategory: {},
        totalTasks: tasks.length,
        completedTasks: tasks.filter(t => t.isCompleted).length,
        dailyBreakdown: [],
        hourlyProductivity: [],
        weekdayBreakdown: {},
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
      [key: string]: { productive: number; wasted: number; neutral: number; total: number };
    } = {};

    // Hourly productivity (0-23)
    let hourlyMap: { [hour: number]: { productive: number; neutral: number; wasted: number; total: number } } = {};
    for (let h = 0; h < 24; h++) {
      hourlyMap[h] = { productive: 0, neutral: 0, wasted: 0, total: 0 };
    }

    // Weekday breakdown (0=Sun, 6=Sat)
    let weekdayMap: { [day: number]: { productive: number; neutral: number; wasted: number; total: number; count: number } } = {};
    for (let d = 0; d < 7; d++) {
      weekdayMap[d] = { productive: 0, neutral: 0, wasted: 0, total: 0, count: 0 };
    }

    // Track days per weekday for averaging
    const weekdayDays: { [day: number]: Set<string> } = {};
    for (let d = 0; d < 7; d++) weekdayDays[d] = new Set();

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

      // Daily breakdown
      const dateKey = new Date(slot.date).toISOString().split('T')[0];
      if (!dailyMap[dateKey]) {
        dailyMap[dateKey] = { productive: 0, wasted: 0, neutral: 0, total: 0 };
      }
      dailyMap[dateKey].total += 20;
      if (slot.productivityType === ProductivityType.PRODUCTIVE) dailyMap[dateKey].productive += 20;
      else if (slot.productivityType === ProductivityType.WASTED) dailyMap[dateKey].wasted += 20;
      else dailyMap[dateKey].neutral += 20;

      // Hourly productivity
      const hourMatch = slot.timeRange.match(/^(\d{2}):/);
      if (hourMatch) {
        const hour = parseInt(hourMatch[1]);
        hourlyMap[hour].total += 20;
        if (slot.productivityType === ProductivityType.PRODUCTIVE) hourlyMap[hour].productive += 20;
        else if (slot.productivityType === ProductivityType.WASTED) hourlyMap[hour].wasted += 20;
        else hourlyMap[hour].neutral += 20;
      }

      // Weekday breakdown
      const slotDate = new Date(slot.date);
      const weekday = slotDate.getDay();
      weekdayMap[weekday].total += 20;
      weekdayDays[weekday].add(dateKey);
      if (slot.productivityType === ProductivityType.PRODUCTIVE) weekdayMap[weekday].productive += 20;
      else if (slot.productivityType === ProductivityType.WASTED) weekdayMap[weekday].wasted += 20;
      else weekdayMap[weekday].neutral += 20;
    });

    const productiveMinutes = productiveCount * 20;
    const wastedMinutes = wastedCount * 20;
    const neutralMinutes = neutralCount * 20;
    const totalMinutes = totalTrackedSlots * 20;
    const productivityPercentage = (productiveMinutes / totalMinutes) * 100;

    // Tasks per day for daily breakdown
    const taskDayMap: { [key: string]: { completed: number; total: number } } = {};
    tasks.forEach(task => {
      const key = new Date(task.date).toISOString().split('T')[0];
      if (!taskDayMap[key]) taskDayMap[key] = { completed: 0, total: 0 };
      taskDayMap[key].total++;
      if (task.isCompleted) taskDayMap[key].completed++;
    });

    const dailyBreakdown = Object.entries(dailyMap)
      .map(([date, data]) => {
        const taskData = taskDayMap[date] || { completed: 0, total: 0 };
        return {
          date,
          ...data,
          productivityPercentage: data.total > 0
            ? parseFloat(((data.productive / data.total) * 100).toFixed(2))
            : 0,
          tasksCompleted: taskData.completed,
          tasksMissed: taskData.total - taskData.completed,
        };
      })
      .sort((a, b) => a.date.localeCompare(b.date));

    // Convert hourly map to array
    const hourlyProductivity = Object.entries(hourlyMap)
      .map(([hour, data]) => ({ hour: parseInt(hour), ...data }))
      .sort((a, b) => a.hour - b.hour);

    // Convert weekday map to averaged values
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const weekdayBreakdown = Object.entries(weekdayMap).map(([day, data]) => {
      const dayCount = weekdayDays[parseInt(day)].size || 1;
      return {
        day: dayNames[parseInt(day)],
        dayIndex: parseInt(day),
        avgProductive: Math.round(data.productive / dayCount),
        avgWasted: Math.round(data.wasted / dayCount),
        avgNeutral: Math.round(data.neutral / dayCount),
        avgTotal: Math.round(data.total / dayCount),
      };
    });

    const totalDays = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    const completedTasks = tasks.filter(t => t.isCompleted).length;
    const daysTracked = Object.keys(dailyMap).length;

    // Productivity Index
    const taskRate = tasks.length > 0 ? (completedTasks / tasks.length) : 0;
    const timeUtil = totalMinutes > 0 ? (productiveMinutes / totalMinutes) : 0;
    const consistency = totalDays > 0 ? Math.min(daysTracked / totalDays, 1) : 0;
    const productivityIndex = Math.round((taskRate * 40) + (timeUtil * 30) + (consistency * 30));

    const responseData = {
      startDate: start.toISOString(),
      endDate: end.toISOString(),
      totalDays,
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
      dailyBreakdown,
      hourlyProductivity,
      weekdayBreakdown,
    };


    await setCache(cacheKey, responseData, 3600); // 1 hour
    res.json(responseData);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};
