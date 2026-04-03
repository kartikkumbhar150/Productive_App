import { Request, Response } from 'express';
import TimeSlot from '../models/TimeSlot';
import {
  getCache, setCache,
  invalidateAnalyticsForDate,
  writeThroughSlotsCache,
  getCachedSlots,
} from '../services/redisService';

// ─── Helper: get all slots for a date as plain objects ──────────────────────
const fetchAndCacheSlots = async (userId: string, dateKey: string, queryDate: Date) => {
  const startOfDay = new Date(queryDate);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(queryDate);
  endOfDay.setHours(23, 59, 59, 999);

  const slots = await TimeSlot.find({
    userId,
    date: { $gte: startOfDay, $lte: endOfDay },
  }).sort({ timeRange: 1 }).lean();

  await writeThroughSlotsCache(userId, dateKey, slots);
  return slots;
};

// @desc    Create or upsert a time slot
// @route   POST /api/slots
export const createTimeSlot = async (req: Request, res: Response) => {
  const { date, timeRange, taskSelected, category, productivityType } = req.body;
  const user = (req as any).user;

  try {
    const queryDate = new Date(date);
    const startOfDay = new Date(queryDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(queryDate);
    endOfDay.setHours(23, 59, 59, 999);
    const dateKey = queryDate.toISOString().split('T')[0];

    const existing = await TimeSlot.findOne({
      userId: user._id,
      timeRange,
      date: { $gte: startOfDay, $lte: endOfDay },
    });

    let result;
    if (existing) {
      existing.taskSelected = taskSelected;
      existing.category = category;
      existing.productivityType = productivityType;
      existing.date = new Date(date);
      await existing.save();
      result = existing;
    } else {
      result = await TimeSlot.create({
        userId: user._id,
        date: new Date(date),
        timeRange,
        taskSelected,
        category,
        productivityType,
      });
    }

    // Write-through: update slot cache immediately, then invalidate analytics
    await fetchAndCacheSlots(user._id.toString(), dateKey, queryDate);
    await invalidateAnalyticsForDate(user._id.toString(), dateKey);

    return res.status(existing ? 200 : 201).json(result);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    Get time slots for a specific date
// @route   GET /api/slots
export const getTimeSlots = async (req: Request, res: Response) => {
  const { date } = req.query;
  const user = (req as any).user;

  try {
    const queryDate = new Date(date as string);
    const dateKey = queryDate.toISOString().split('T')[0];

    const cached = await getCachedSlots(user._id.toString(), dateKey);
    if (cached) {
      // Set cache-control header so clients know it's cached
      res.set('X-Cache', 'HIT');
      return res.json(cached);
    }

    const slots = await fetchAndCacheSlots(user._id.toString(), dateKey, queryDate);
    res.set('X-Cache', 'MISS');
    res.json(slots);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    Update a time slot
// @route   PUT /api/slots/:id
export const updateTimeSlot = async (req: Request, res: Response) => {
  const { id } = req.params;
  const { taskSelected, category, productivityType } = req.body;
  const user = (req as any).user;

  try {
    const slot = await TimeSlot.findOne({ _id: id, userId: user._id });
    if (!slot) return res.status(404).json({ message: 'Time slot not found' });

    if (taskSelected !== undefined) slot.taskSelected = taskSelected;
    if (category !== undefined) slot.category = category;
    if (productivityType !== undefined) slot.productivityType = productivityType;
    await slot.save();

    const dateKey = new Date(slot.date).toISOString().split('T')[0];
    const queryDate = new Date(slot.date);
    await fetchAndCacheSlots(user._id.toString(), dateKey, queryDate);
    await invalidateAnalyticsForDate(user._id.toString(), dateKey);

    res.json(slot);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    Delete a time slot
// @route   DELETE /api/slots/:id
export const deleteTimeSlot = async (req: Request, res: Response) => {
  const { id } = req.params;
  const user = (req as any).user;

  try {
    const slot = await TimeSlot.findOneAndDelete({ _id: id, userId: user._id });
    if (!slot) return res.status(404).json({ message: 'Time slot not found' });

    const dateKey = new Date(slot.date).toISOString().split('T')[0];
    const queryDate = new Date(slot.date);
    await fetchAndCacheSlots(user._id.toString(), dateKey, queryDate);
    await invalidateAnalyticsForDate(user._id.toString(), dateKey);

    res.json({ message: 'Time slot deleted' });
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};

// @desc    Batch upsert multiple time slots at once
// @route   PATCH /api/slots/batch
export const batchUpdateTimeSlots = async (req: Request, res: Response) => {
  const { date, timeRanges, taskSelected, category, productivityType } = req.body;
  const user = (req as any).user;

  if (!Array.isArray(timeRanges) || timeRanges.length === 0) {
    return res.status(400).json({ message: 'timeRanges must be a non-empty array' });
  }

  try {
    const queryDate = new Date(date);
    const startOfDay = new Date(queryDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(queryDate);
    endOfDay.setHours(23, 59, 59, 999);
    const dateKey = queryDate.toISOString().split('T')[0];

    const results = await Promise.all(
      timeRanges.map(async (timeRange: string) => {
        const existing = await TimeSlot.findOne({
          userId: user._id,
          timeRange,
          date: { $gte: startOfDay, $lte: endOfDay },
        });

        if (existing) {
          existing.taskSelected = taskSelected;
          existing.category = category;
          existing.productivityType = productivityType;
          await existing.save();
          return existing;
        } else {
          return TimeSlot.create({
            userId: user._id,
            date: new Date(date),
            timeRange,
            taskSelected,
            category,
            productivityType,
          });
        }
      })
    );

    // Write-through then invalidate analytics
    await fetchAndCacheSlots(user._id.toString(), dateKey, queryDate);
    await invalidateAnalyticsForDate(user._id.toString(), dateKey);

    res.json(results);
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};
