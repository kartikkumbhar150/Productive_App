import { Request, Response } from 'express';
import TimeSlot from '../models/TimeSlot';

// @desc    Create a new time slot
// @route   POST /api/slots
export const createTimeSlot = async (req: Request, res: Response) => {
  const { date, timeRange, taskSelected, category, productivityType } = req.body;
  const user = (req as any).user;

  try {
    // Check if slot already exists for this user + date + timeRange
    const queryDate = new Date(date);
    const startOfDay = new Date(queryDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(queryDate);
    endOfDay.setHours(23, 59, 59, 999);

    const existing = await TimeSlot.findOne({
      userId: user._id,
      timeRange,
      date: { $gte: startOfDay, $lte: endOfDay }
    });

    if (existing) {
      // Update existing slot instead of creating duplicate
      existing.taskSelected = taskSelected;
      existing.category = category;
      existing.productivityType = productivityType;
      existing.date = new Date(date);
      await existing.save();
      return res.status(200).json(existing);
    }

    const slot = await TimeSlot.create({
      userId: user._id,
      date: new Date(date),
      timeRange,
      taskSelected,
      category,
      productivityType,
    });

    res.status(201).json(slot);
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
    const startOfDay = new Date(queryDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(queryDate);
    endOfDay.setHours(23, 59, 59, 999);

    const slots = await TimeSlot.find({
      userId: user._id,
      date: { $gte: startOfDay, $lte: endOfDay }
    }).sort({ timeRange: 1 });

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
    if (!slot) {
      return res.status(404).json({ message: 'Time slot not found' });
    }

    if (taskSelected !== undefined) slot.taskSelected = taskSelected;
    if (category !== undefined) slot.category = category;
    if (productivityType !== undefined) slot.productivityType = productivityType;

    await slot.save();
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
    if (!slot) {
      return res.status(404).json({ message: 'Time slot not found' });
    }
    res.json({ message: 'Time slot deleted' });
  } catch (error: any) {
    res.status(400).json({ message: error.message });
  }
};
