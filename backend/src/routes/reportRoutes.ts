import express from 'express';
import { getReport } from '../controllers/reportController';
import { protect } from '../middleware/authMiddleware';

const router = express.Router();

router.get('/', protect, getReport);

export default router;
