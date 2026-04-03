import express from 'express';
import {
  createTimeSlot,
  getTimeSlots,
  updateTimeSlot,
  deleteTimeSlot,
  batchUpdateTimeSlots,
} from '../controllers/slotController';
import { protect } from '../middleware/authMiddleware';

const router = express.Router();

// Batch route must come BEFORE /:id to avoid route conflict
router.route('/batch').patch(protect, batchUpdateTimeSlots);

router.route('/')
  .post(protect, createTimeSlot)
  .get(protect, getTimeSlots);

router.route('/:id')
  .put(protect, updateTimeSlot)
  .delete(protect, deleteTimeSlot);

export default router;
