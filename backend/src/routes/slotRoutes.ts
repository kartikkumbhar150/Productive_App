import express from 'express';
import { createTimeSlot, getTimeSlots, updateTimeSlot, deleteTimeSlot } from '../controllers/slotController';
import { protect } from '../middleware/authMiddleware';

const router = express.Router();

router.route('/')
  .post(protect, createTimeSlot)
  .get(protect, getTimeSlots);

router.route('/:id')
  .put(protect, updateTimeSlot)
  .delete(protect, deleteTimeSlot);

export default router;
