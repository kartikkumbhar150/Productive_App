# Clario — TrackYourTime

A full-stack productivity tracking app built around **20-minute time blocks**, with task planning, category management, comprehensive productivity analytics, full offline-first synchronization, and AI-generated coaching feedback.

This repository contains:
- A **Flutter frontend** (Mobile + Web capable) with robust offline local storage and background sync.
- A **Node.js/Express + TypeScript backend** with MongoDB, high-speed Redis caching, and Groq-powered AI insights.

---

## 📖 Table of Contents

1. [Features & Improvements](#features--improvements)
2. [Tech Stack](#tech-stack)
3. [Architecture & Data Models](#architecture--data-models)
4. [API Reference (Detailed)](#api-reference-detailed)
5. [Local Development Setup](#local-development-setup)
6. [Environment Variables](#environment-variables)
7. [Deployment & Production Config](#deployment--production-config)
8. [Known Limitations & Troubleshooting](#known-limitations--troubleshooting)
9. [Roadmap](#roadmap)

---

## ✨ Features & Improvements

### 1) Authentication & User Management
- **Secure Access**: Email/password registration and login secured with JWT and bcrypt password hashing.
- **Profile Customization**: Users can update names and profile photo references.
- **Custom Categories**: Users can manage custom time categories (e.g., Study, Work, Exercise, Leisure).

### 2) Core Philosophy: 20-Minute Time Slot Tracking
- **Granular Accountability**: The day is represented as a series of deliberate 20-minute blocks.
- **Productivity Labels**: Time is tagged as `Productive`, `Neutral`, or `Wasted`.
- **Full CRUD for Slots**: Users can seamlessly create, update, and delete logged time slots dynamically.

### 3) Immutable Task Planning
- **Daily Tasks**: Create tasks mapped strictly to dates.
- **Task Progression**: Mark tasks as completed with non-blocking UI updates ensuring high responsiveness.
- **Constrained Editing**: Task renaming is intentionally constrained to encourage commitment, though flexible deletions and insertions are supported.

### 4) Comprehensive Analytics Engine
- **Period Agnostic Views**: Easily fetch `day` or `week` reporting summaries.
- **Metrics Calculated**:
  - Total minutes / Productive minutes / Wasted minutes.
  - Overall Productivity Percentage.
  - Deep category and task breakdown distributions.
- **Weekly Trends & Heatmaps**: Visualize productivity flow across the broader week using dense Heatmap capabilities.

### 5) 🤖 AI-Generated Coaching Insights
- Integrated securely with the **Groq SDK**. The backend packages a compact analytical payload of daily behaviors and queries an LLM pipeline to return actionable coaching feedback. It elegantly falls back to localized strings if the API limit is reached.

### 6) 🚀 Performance & Sync Improvements
- **Offline-First Implementation**: Operated via a highly responsive frontend (`local_db_service.dart`) utilizing local databases to cache the session.
- **Background Sync Engine**: Allows modifying, creating, and deleting records dynamically without network wait times (`offline_sync_service.dart`). Syncs delta changes automatically when connectivity resumes.
- **Redis Caching Pipeline**: On the backend level, heavy analytical operations, trend compilations, and heatmaps traverse a Redis caching layer, significantly dropping payload response times. Cache invalidation operates surgically per user changes.
- **Automated Summary Reports**: node-cron fires at exactly `23:55` daily to aggregate unclosed user cycles into a formal, permanent `Report` document.

---

## 🛠 Tech Stack

### Frontend
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Storage/Sync**: Native SharedPreferences & Custom Local DB queues
- **UI Elements**: fl_chart (for beautiful data/heatmaps visual elements)
- **Networking**: Dart HTTP clients natively formatted for REST.

### Backend
- **Environment**: Node.js + Express
- **Language**: TypeScript
- **Database**: MongoDB + Mongoose
- **Cache Layer**: Redis (ioredis)
- **Authentication**: JWT + bcryptjs
- **Scheduling**: node-cron
- **AI Integration**: Groq SDK

---

## 📊 Architecture & Data Models

### User
- `name`, `email`, `password` (hashed payload)
- `profilePhoto` (optional URL string)
- `categories` (array of strings, user-defined, populated with defaults)

### Task
- `userId` (ObjectId bound)
- `taskName` (String)
- `date` (Date object bounding the task to a day)
- `isCompleted` (Boolean threshold)

### TimeSlot
- `userId` (ObjectId)
- `date` (Date object mapping slot bounds)
- `timeRange` (String pattern, e.g. "09:00-09:20")
- `taskSelected` (String mapping to the active duty)
- `category` (String mapping to broader groups)
- `productivityType` (Enum explicitly spanning `Productive` | `Neutral` | `Wasted`)

### Report
- `userId` (ObjectId)
- `date` (Date object defining compiled end target)
- `summary` (String - compilation message)
- `productivityScore` (Decimal index measuring 0-100 efficiency)

---

## 📡 API Reference (Detailed)

> Base URL routing prefix: `/api`
> Most endpoints enforce `Authorization: Bearer <token>` through the middleware.

### 🔐 Authentication (`/api/auth/*`)
- **`POST /register`**: Registers a new user session. Needs `{ name, email, password }`. Generates user document and initial categories.
- **`POST /login`**: Validates `{ email, password }` and releases a signed JWT.
- **`GET /me`**: Provides full resolution of currently signed-in user payload.

### 👤 Users (`/api/users/*`)
- **`GET /profile`**: Fetches identity details.
- **`PUT /profile`**: Updates identity fields `{ name, profilePhoto }`.
- **`GET /categories`**: Returns an array of customized category strings.
- **`PUT /categories`**: Completely overrides category mapping, sending `{ categories: ["...", "..."] }`.

### 📋 Tasks (`/api/tasks/*`)
- **`GET /`**: Pull all tasks. Sift by query param `?date=<YYYY-MM-DD>`.
- **`POST /`**: Stage a new task `{ taskName, date }`.
- **`PUT /:id`**: Edits arbitrary attributes of a task dynamically.
- **`DELETE /:id`**: Strip a task from the board permanently.
- **`PUT /:id/complete`**: Marks `isCompleted: true`.

### ⏳ Time Slots (`/api/slots/*`)
- **`GET /`**: Fetches sequentially ordered blocks of 20-min slots tracked `?date=<YYYY-MM-DD>`.
- **`POST /`**: Posts an entry log. Needs `{ date, timeRange, taskSelected, category, productivityType }`. Intelligently performs an UPSERT (Update or Insert) rule: overriding existing identical ranges for the same day to maintain 1:1 timeline continuity.
- **`PUT /:id`**: Modify any metadata around an already logged ID directly.
- **`DELETE /:id`**: Wipes out a specific block of tracked history.

### 📈 Analytics (`/api/analytics/*`)
> *Responses via these controllers automatically bridge with the Redis cache.*
- **`GET /weekly-trend`**: Rebuilds absolute trajectories of the trailing week performance metrics.
- **`GET /heatmap`**: Issues intense categorical data mapping coordinate heat strengths for UI ingestion.
- **`GET /:period`**: Parameterezes `day` or `week`. (E.g. `/api/analytics/day?date=2024-03-31`). Returns calculated:
   - Absolute minutes mapping (Productive, Wasted, Neutral, Total).
   - Productivity %.
   - Array segmentations tracking the specific weight of custom categories.
   - Array task allocations.

### 🤖 AI Coaching (`/api/ai/*`)
- **`GET /insights`**: Triggers a backend-to-Groq request encapsulating the context of user activities to fetch customized string directives and improvements.

### 📄 Reports (`/api/reports/*`)
- **`GET /`**: Lists historically verified scores injected systematically by the backend daily cron processor. 

---

## 💻 Local Development Setup

### Prerequisites
- Node.js 18+ and npm 9+
- Flutter SDK (stable channel, matching `pubspec.yaml`)
- MongoDB Local Instance or Atlas URL
- Redis Server (Native / Dockerized / Cloud)

### Frontend (Flutter)
```bash
cd frontend
flutter pub get
```
You MUST update the URL pathing internally in `frontend/lib/core/api_config.dart`.
- Normal Web / Host target: `http://localhost:5000/api`
- Android Emulator target: `http://10.0.2.2:5000/api`
```bash
flutter run
```

### Backend (Express)
```bash
cd backend
npm install
```
Setup your local `.env`, and engage nodemon:
```bash
npm run dev
```

---

## 🔒 Environment Variables

Copy to `backend/.env`:

```env
PORT=5000
MONGO_URI=<your-mongodb-connection-string>
REDIS_URI=<your-redis-connection-string-for-caching>
JWT_SECRET=<your-very-strong-jwt-secret>
GROQ_API_KEY=<groq-portal-key-optional>
NODE_ENV=development
```

Note: Passing an empty `REDIS_URI` degrades caching but will not halt the application. Missing `GROQ_API_KEY` reverts to a fallback string generator for insights safely.

---

## ☁️ Deployment & Production Config

- Refer strictly to `backend/deployment_guide.md` if pushing directly to **Vercel** serverless configurations. 
- Due to the nature of serverless, `node-cron` skips memory instantiation under `NODE_ENV=production`. You will need to trigger cron operations using cloud provider cron-schedulers mapping to an independent `/api/reports/trigger` route conceptually.

---

## 🚧 Known Limitations & Troubleshooting

- **Server Connection**: The most common initialization issue is connecting Flutter over Android. Be absolutely sure `10.0.2.2:5000` is targeted and ensure your machine's firewall allows inbound port `5000`.
- **Timezone Drift**: Analytics assumes 20-minute slot increments uniformly and handles Date objects locally. Severe cross-timezone usage across devices simultaneously requires active UI refreshing.
- **Offline Sync Rejection**: In rare cases of heavily disjointed edits, the offline queue sync will heavily prioritize the most *recently* verified backend state. Pull-to-refresh will hard reset client states in misalignment.

---

## 🗺 Roadmap

- **Push Notifications via Firebase** tracking unlogged gaps.
- Full OAuth2 pipeline integration for seamless Google Sign-In.
- Dark/Light automatic UI parity based on native device styling.
- Export mechanism downloading fully structured PDF reports of analytics tables over the spanning calendar year. 
