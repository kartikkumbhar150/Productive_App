import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { connectDB } from './config/db';
import taskRoutes from './routes/taskRoutes';
import slotRoutes from './routes/slotRoutes';
import authRoutes from './routes/authRoutes';
import userRoutes from './routes/userRoutes';
import analyticsRoutes from './routes/analyticsRoutes';
import reportRoutes from './routes/reportRoutes';
import { initCronJobs } from './services/cronService';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

connectDB();

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/slots', slotRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/reports', reportRoutes);

app.get('/', (req, res) => res.send('Productivity API is running'));

// Only run cron jobs if not in a Vercel serverless environment 
// (Vercel has its own cron setup via vercel.json)
if (process.env.NODE_ENV !== 'production') {
  initCronJobs();
}

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

export default app; // Export for Vercel Serverless
