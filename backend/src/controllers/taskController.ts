import { Request, Response } from 'express';
import Task from '../models/Task';
import { getCache, setCache, invalidateUserAnalytics, deleteCacheKeys } from '../services/redisService';

// @desc    Create a new task (Immutable once created)
// @route   POST /api/tasks
export const createTask = async (req: Request, res: Response) => {
  const { taskName, date } = req.body;
  const user = (req as any).user;

  try {
    const task = await Task.create({
      userId: user._id,
      taskName,
      date: new Date(date),
      isCompleted: false
    });

    const dateKey = new Date(date).toISOString().split('T')[0];
    await deleteCacheKeys([`user:${user._id}:tasks:${dateKey}`]);
    await invalidateUserAnalytics(user._id.toString());

    res.status(201).json(task);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    Get tasks for a specific date
// @route   GET /api/tasks
export const getTasks = async (req: Request, res: Response) => {
  const { date } = req.query;
  const user = (req as any).user;

  try {
    const queryDate = new Date(date as string);
    const dateKey = queryDate.toISOString().split('T')[0];
    const cacheKey = `user:${user._id}:tasks:${dateKey}`;
    const cachedData = await getCache(cacheKey);
    if (cachedData) return res.json(cachedData);

    const startOfDay = new Date(queryDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(queryDate);
    endOfDay.setHours(23, 59, 59, 999);

    const tasks = await Task.find({
      userId: user._id,
      date: { $gte: startOfDay, $lte: endOfDay }
    });
    
    await setCache(cacheKey, tasks, 3600); // 1 hour
    res.json(tasks);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// Mark completed (Only modification allowed)
export const markTaskCompleted = async (req: Request, res: Response) => {
  const { id } = req.params;
  const user = (req as any).user;

  try {
    const task = await Task.findOne({ _id: id, userId: user._id });
    if (!task) return res.status(404).json({ message: 'Task not found' });

    task.isCompleted = true;
    await task.save();

    const dateKey = new Date(task.date).toISOString().split('T')[0];
    await deleteCacheKeys([`user:${user._id}:tasks:${dateKey}`]);
    await invalidateUserAnalytics(user._id.toString());

    res.json(task);
  } catch(error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    RESTRICTED — Tasks are immutable
// @route   PUT /api/tasks/:id
export const updateTask = async (_req: Request, res: Response) => {
  return res.status(403).json({
    message: 'Tasks are immutable. Once created, they cannot be edited.',
    code: 'IMMUTABLE_TASK'
  });
};

// @desc    RESTRICTED — Tasks are immutable
// @route   DELETE /api/tasks/:id
export const deleteTask = async (_req: Request, res: Response) => {
  return res.status(403).json({
    message: 'Tasks are immutable. Once created, they cannot be deleted.',
    code: 'IMMUTABLE_TASK'
  });
};
