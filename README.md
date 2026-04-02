# Clario — TrackYourTime

A full-stack productivity tracking app built around **20-minute time blocks**, with task planning, category management, productivity analytics, and AI-generated coaching feedback.

This repository contains:
- A **Flutter frontend** (mobile + web capable)
- A **Node.js/Express + TypeScript backend** with MongoDB

---

## Table of Contents

1. [What this project does](#what-this-project-does)
2. [Core product philosophy](#core-product-philosophy)
3. [Repository structure](#repository-structure)
4. [Tech stack](#tech-stack)
5. [Feature walkthrough](#feature-walkthrough)
6. [How data is modeled](#how-data-is-modeled)
7. [API reference](#api-reference)
8. [Local development setup](#local-development-setup)
9. [Frontend setup (Flutter)](#frontend-setup-flutter)
10. [Backend setup (Express + MongoDB)](#backend-setup-express--mongodb)
11. [Environment variables](#environment-variables)
12. [Running the app end-to-end](#running-the-app-end-to-end)
13. [Analytics and AI insights details](#analytics-and-ai-insights-details)
14. [Cron job behavior](#cron-job-behavior)
15. [Deployment notes](#deployment-notes)
16. [Security and auth notes](#security-and-auth-notes)
17. [Known limitations / implementation notes](#known-limitations--implementation-notes)
18. [Troubleshooting](#troubleshooting)
19. [Suggested roadmap](#suggested-roadmap)
20. [License](#license)

---

## What this project does

Clario helps users create structure in their day through:

- **Immutable daily tasks** (create + complete)
- **20-minute time slot tracking** with productivity labels:
  - `Productive`
  - `Neutral`
  - `Wasted`
- **Per-category and per-task analytics**
- **AI-generated coaching insights** based on tracked behavior
- **Customizable user categories**
- **Basic profile management** (name + profile photo string)

The backend exposes REST APIs consumed by the Flutter client.

---

## Core product philosophy

The project uses **behavioral accountability by granularity**:

- Day is represented as a series of short, deliberate blocks.
- Tracking happens at a small unit (20 minutes), reducing “I’ll do it later” ambiguity.
- Analytics are generated from **actual logged slots** instead of estimated completion claims.
- Task editing is intentionally constrained to encourage commitment and reduce over-optimization.

---

## Repository structure

```text
Clario_TrackYourTime/
├── backend/
│   ├── src/
│   │   ├── config/            # DB connection
│   │   ├── controllers/       # Route handlers
│   │   ├── middleware/        # Auth middleware
│   │   ├── models/            # Mongoose models
│   │   ├── routes/            # Express route definitions
│   │   └── services/          # Groq + cron logic
│   ├── deployment_guide.md
│   ├── package.json
│   ├── tsconfig.json
│   └── vercel.json
└── frontend/
    ├── lib/
    │   ├── core/              # Theme + API config
    │   ├── models/            # App models
    │   ├── providers/         # State management
    │   ├── screens/           # UI screens
    │   └── services/          # API service layer
    ├── pubspec.yaml
    └── ... platform folders
```

---

## Tech stack

### Frontend
- Flutter (Dart)
- Provider (state management)
- HTTP client
- Shared Preferences (token/session persistence)
- fl_chart (analytics charting)

### Backend
- Node.js + Express
- TypeScript
- MongoDB + Mongoose
- JWT authentication
- bcryptjs password hashing
- node-cron
- Groq SDK (LLM feedback generation)

---

## Feature walkthrough

## 1) Authentication

- Email/password register
- Email/password login
- JWT returned and stored client-side
- Authenticated `/me` and protected routes

## 2) Task management

- Create a task with date and name
- Fetch tasks for a specific day
- Mark task complete
- No rename/delete endpoint (intentional immutable rule)

## 3) Time slot tracking

- Create time slot entries with:
  - date
  - timeRange (e.g., `09:00-09:20`)
  - taskSelected
  - category
  - productivityType
- If slot for same user + day + time range already exists, backend updates existing slot instead of duplicating.
- Fetch, update, and delete supported.

## 4) Categories

- Default categories initialized on user model
- Fetch categories
- Replace categories list

## 5) Analytics

- Fetch day/week analytics by date
- Computes:
  - total/productive/wasted/neutral minutes
  - productivity %
  - category breakdown
  - task breakdown
  - productivity by category
- Optionally includes AI summary from Groq API.

## 6) Profile

- Fetch profile
- Update name and profile photo field

---

## How data is modeled

## User
Fields include:
- `name`, `email`, optional `password`
- optional `googleId`
- optional `profilePhoto`
- `categories` array with defaults

Password hashing occurs in a Mongoose pre-save hook.

## Task
- `userId`
- `taskName`
- `date`
- `isCompleted`

## TimeSlot
- `userId`
- `date`
- `timeRange`
- `taskSelected` (mixed type)
- `category`
- `productivityType` enum (`Productive` | `Neutral` | `Wasted`)

## Report
- Used by cron summary logic
- Stores end-of-day summary and score

---

## API reference

> Base prefix: `/api`

## Auth

### `POST /auth/register`
Body:
```json
{ "name": "Ada", "email": "ada@example.com", "password": "secret123" }
```

### `POST /auth/login`
Body:
```json
{ "email": "ada@example.com", "password": "secret123" }
```

### `GET /auth/me`
Requires `Authorization: Bearer <token>`

---

## User

### `GET /users/categories`
Get current user categories.

### `PUT /users/categories`
Body:
```json
{ "categories": ["Study", "Work", "Gym"] }
```

### `GET /users/profile`
Get profile.

### `PUT /users/profile`
Body example:
```json
{ "name": "Ada Lovelace", "profilePhoto": "https://..." }
```

---

## Tasks

### `POST /tasks`
Body:
```json
{ "taskName": "Revise system design", "date": "2026-03-31T09:00:00.000Z" }
```

### `GET /tasks?date=<iso-date>`
Returns tasks for the provided day.

### `PUT /tasks/:id/complete`
Marks task completed.

---

## Slots

### `POST /slots`
Body:
```json
{
  "date": "2026-03-31T09:00:00.000Z",
  "timeRange": "09:00-09:20",
  "taskSelected": "Revise system design",
  "category": "Study",
  "productivityType": "Productive"
}
```

### `GET /slots?date=<iso-date>`
Returns slots for day sorted by `timeRange`.

### `PUT /slots/:id`
Partial update of slot fields.

### `DELETE /slots/:id`
Deletes one slot.

---

## Analytics

### `GET /analytics/:period?date=<iso-date>`
Where `period` is currently `day` or `week`.

Response includes:
- minute totals
- productivity percentage
- category/task breakdown
- category productivity map
- AI insights text

---

## Local development setup

## Prerequisites
- Node.js 18+
- npm 9+
- Flutter SDK (matching Dart SDK constraints in `pubspec.yaml`)
- MongoDB instance (local or hosted)

---

## Frontend setup (Flutter)

```bash
cd frontend
flutter pub get
```

Update API base URL in:
- `frontend/lib/core/api_config.dart`

Current default:
- `http://192.168.1.103:5000/api`

For Android emulator typically use:
- `http://10.0.2.2:5000/api`

Run app:
```bash
flutter run
```

---

## Backend setup (Express + MongoDB)

```bash
cd backend
npm install
```

Create `.env` (see next section), then:

```bash
npm run dev
```

For production build:

```bash
npm run build
npm start
```

---

## Environment variables

Create `backend/.env`:

```env
PORT=5000
MONGO_URI=<your-mongodb-connection-string>
JWT_SECRET=<your-strong-jwt-secret>
GOOGLE_CLIENT_ID=<optional-or-future-use>
GROQ_API_KEY=<optional-for-ai-insights>
NODE_ENV=development
```

Notes:
- If `GROQ_API_KEY` is missing, analytics still work, but insight text falls back to a helper message.
- `JWT_SECRET` has a fallback in code, but you should always define a strong secret in real environments.

---

## Running the app end-to-end

1. Start backend on port 5000.
2. Ensure frontend `ApiConfig.baseUrl` points to the running backend.
3. Run Flutter app.
4. Register a new account.
5. Create tasks for today.
6. Fill time slots.
7. Open analytics/dashboard and validate computed metrics.

---

## Analytics and AI insights details

The analytics logic assumes each slot equals **20 minutes**.

From slots in selected period, backend computes:
- `productiveMinutes = productiveSlotCount * 20`
- `wastedMinutes = wastedSlotCount * 20`
- `neutralMinutes = neutralSlotCount * 20`
- `totalMinutes = totalSlotCount * 20`
- `productivityPercentage = productiveMinutes / totalMinutes * 100`

Then it constructs category/task maps and sends a compact prompt payload to Groq for feedback generation.

If Groq call fails, API still returns analytics with fallback insights text.

---

## Cron job behavior

- A cron job is registered (non-production mode) to run at `23:55` daily.
- It scans each user’s tasks for the day.
- Creates a `Report` with completion summary + productivity score.

Important:
- In production/serverless environments like Vercel, built-in cron execution differs; backend code conditionally skips local cron init under production mode.

---

## Deployment notes

Backend includes `backend/deployment_guide.md` with Vercel-focused steps.

Summary:
- Install Vercel CLI
- Run deploy from `backend`
- Ensure environment variables are configured in Vercel settings
- `vercel.json` maps API requests to Express entrypoint

---

## Security and auth notes

- Auth uses bearer JWT on protected endpoints.
- Passwords are hashed with bcrypt pre-save hook.
- CORS is enabled globally.
- There is currently no rate limiting or refresh token flow.

Recommended hardening before production:
- Add helmet, request throttling, and stricter CORS origin config.
- Add token revocation or short-lived access + refresh pattern.
- Add validation layer (e.g., zod/joi) for all request payloads.
- Remove fallback secrets and enforce required env vars on boot.

---

## Known limitations / implementation notes

- `GOOGLE_CLIENT_ID` is present in env guidance but Google auth endpoints are not active in current API routes.
- Slot “upsert by day + timeRange” behavior is helpful but should be clearly represented in UI to avoid confusion.
- Timezone handling relies on JavaScript Date; cross-timezone users may need explicit locale/day-boundary normalization.
- `taskSelected` in slots is mixed type (string/object id), which is flexible but can complicate strict typing and analytics consistency.
- Flutter API base URL is hard-coded and should ideally be environment-driven for multiple targets.

---

## Troubleshooting

## Backend won’t start
- Verify `.env` exists in `backend`.
- Confirm `MONGO_URI` is reachable.
- Confirm port is not occupied.

## Unauthorized errors on protected routes
- Ensure login/register was successful and token stored.
- Confirm requests include `Authorization: Bearer <token>`.

## No AI insights shown
- Set `GROQ_API_KEY`.
- Check backend logs for Groq API errors.

## App can’t reach backend from emulator/device
- Use correct host for your runtime:
  - Android emulator: `10.0.2.2`
  - iOS simulator: often `localhost`
  - Physical device: host machine LAN IP
- Ensure firewall allows inbound port 5000.

---

## Suggested roadmap

- Add refresh token auth + secure storage strategy.
- Add Google sign-in endpoints and complete OAuth flow.
- Add task delete/archive with audit trail.
- Add recurring tasks and habit templates.
- Add monthly analytics and trend comparisons.
- Add export/report download (CSV/PDF).
- Add CI checks (lint/test/build) and pre-commit hooks.
- Add containerized dev environment (Docker Compose: Flutter web + API + Mongo).

---

## License

No license file is currently present in this repository.
If you intend this to be open source, add a `LICENSE` file (e.g., MIT/Apache-2.0) and update this section.
