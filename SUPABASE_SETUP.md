# TripCraft - Supabase & Environment Setup Guide

This guide walks you through setting up Supabase and configuring environment variables for the TripCraft project.

---

## 1. Create Supabase Project

### Steps:
1. Go to [https://supabase.com](https://supabase.com)
2. Sign up or log in
3. Click **"New Project"**
4. Fill in:
   - **Organization**: Select or create one
   - **Project Name**: `tripcraft` (or your preferred name)
   - **Database Password**: Generate a strong password (save it!)
   - **Region**: Choose closest to your users
5. Click **"Create new project"** (takes ~2 minutes)

### After Creation:
- Go to **Settings** → **API** to find your keys:
  - `SUPABASE_URL`: Your project URL (e.g., `https://xyz.supabase.co`)
  - `SUPABASE_ANON_KEY`: Public key for frontend
  - `SUPABASE_SERVICE_KEY`: Secret key for backend (never expose!)

---

## 2. Set Up Database Schema

### Option A: Using Supabase SQL Editor

1. Go to **SQL Editor** in Supabase dashboard
2. Click **"New query"**
3. Paste the SQL below and click **"Run"**

### Option B: Using Migration Files (Recommended)

Create the schema file locally and run via Alembic later.

### SQL Schema:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on email for faster lookups
CREATE INDEX idx_users_email ON users(email);

-- Trips table
CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT,
  destination TEXT NOT NULL,
  start_date DATE,
  end_date DATE,
  travel_style TEXT,
  budget_tier TEXT,
  preferences TEXT,
  total_budget_estimate NUMERIC DEFAULT 0,
  local_tips TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for trips
CREATE INDEX idx_trips_user_id ON trips(user_id);
CREATE INDEX idx_trips_destination ON trips(destination);
CREATE INDEX idx_trips_start_date ON trips(start_date);

-- Days table
CREATE TABLE days (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  day_index INTEGER NOT NULL,
  date DATE,
  summary TEXT,
  total_day_budget NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for days
CREATE INDEX idx_days_trip_id ON days(trip_id);
CREATE INDEX idx_days_day_index ON days(trip_id, day_index);

-- Activities table
CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  day_id UUID NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  start_time TIME,
  end_time TIME,
  location TEXT,
  details TEXT,
  estimated_cost NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for activities
CREATE INDEX idx_activities_day_id ON activities(day_id);

-- Notes table
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
  day_id UUID REFERENCES days(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT note_belongs_to_trip_or_day CHECK (
    (trip_id IS NOT NULL AND day_id IS NULL) OR
    (trip_id IS NULL AND day_id IS NOT NULL)
  )
);

-- Create indexes for notes
CREATE INDEX idx_notes_trip_id ON notes(trip_id);
CREATE INDEX idx_notes_day_id ON notes(day_id);

-- Budget items table
CREATE TABLE budget_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
  day_id UUID REFERENCES days(id) ON DELETE CASCADE,
  category TEXT,
  amount NUMERIC DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT budget_belongs_to_trip_or_day CHECK (
    (trip_id IS NOT NULL AND day_id IS NULL) OR
    (trip_id IS NULL AND day_id IS NOT NULL)
  )
);

-- Create indexes for budget_items
CREATE INDEX idx_budget_items_trip_id ON budget_items(trip_id);
CREATE INDEX idx_budget_items_day_id ON budget_items(day_id);

-- Optional: Embeddings table for semantic search (pgvector)
-- Uncomment if implementing BE-6
/*
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE embeddings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
  note_id UUID REFERENCES notes(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  embedding vector(1536),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_embeddings_vector ON embeddings USING ivfflat (embedding vector_cosine_ops);
*/

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON trips
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notes_updated_at BEFORE UPDATE ON notes
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## 3. Set Up Supabase Storage for PDFs

### Steps:
1. Go to **Storage** in Supabase dashboard
2. Click **"New bucket"**
3. Configure:
   - **Name**: `trip-pdfs`
   - **Public bucket**: ✅ Yes (for signed URLs)
   - **File size limit**: 10 MB (or higher if needed)
   - **Allowed MIME types**: `application/pdf`
4. Click **"Create bucket"**

### Set Up Storage Policies (Optional - for better security):

Go to **Storage** → **Policies** and add:

```sql
-- Policy: Allow authenticated users to upload their own PDFs
CREATE POLICY "Users can upload their own PDFs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'trip-pdfs' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Policy: Allow users to read their own PDFs
CREATE POLICY "Users can read their own PDFs"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'trip-pdfs' AND auth.uid()::text = (storage.foldername(name))[1]);
```

---

## 4. Configure Environment Variables

### Backend Environment Variables

Create `tripcraft-backend/.env`:

```env
# Database
DATABASE_URL=postgresql://postgres:[YOUR-DB-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres

# Supabase
SUPABASE_URL=https://[YOUR-PROJECT-REF].supabase.co
SUPABASE_SERVICE_KEY=[YOUR-SERVICE-ROLE-KEY]

# JWT Configuration
JWT_SECRET=[GENERATE-RANDOM-HEX-STRING]
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

# Groq AI
GROQ_API_KEY=sk-[YOUR-GROQ-KEY]

# PDF Export
PDF_TEMP_PATH=/tmp
PDF_STORAGE_BUCKET=trip-pdfs

# Rate Limiting
RATE_LIMIT_GENERATE_PER_DAY=30
RATE_LIMIT_REFINE_PER_DAY=100

# Optional: pgvector for embeddings
PGVECTOR_ENABLED=false

# Environment
ENVIRONMENT=development
DEBUG=true
```

### Backend `.env.example` (for Git):

Create `tripcraft-backend/.env.example`:

```env
# Database
DATABASE_URL=postgresql://postgres:your-password@host:5432/dbname

# Supabase
SUPABASE_URL=https://xyz.supabase.co
SUPABASE_SERVICE_KEY=your-service-key

# JWT Configuration
JWT_SECRET=generate-random-hex-64-chars
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

# Groq AI
GROQ_API_KEY=sk-your-groq-key

# PDF Export
PDF_TEMP_PATH=/tmp
PDF_STORAGE_BUCKET=trip-pdfs

# Rate Limiting
RATE_LIMIT_GENERATE_PER_DAY=30
RATE_LIMIT_REFINE_PER_DAY=100

# Optional
PGVECTOR_ENABLED=false

# Environment
ENVIRONMENT=development
DEBUG=true
```

---

### Frontend Environment Variables

Create `tripcraft_app/lib/src/constants.dart`:

```dart
// constants.dart
const String API_BASE_URL = 'http://localhost:8000/api/v1'; // For local dev
// const String API_BASE_URL = 'https://your-api.railway.app/api/v1'; // For production

const String HIVE_BOX_TRIPS = 'trips_box';
const String JWT_KEY = 'jwt_token';
const String USER_KEY = 'user_data';

// App Configuration
const int API_TIMEOUT_SECONDS = 15;
const int MAX_RETRY_ATTEMPTS = 3;
const int RETRY_DELAY_MS = 1000;

// Generation Limits
const int MAX_TRIP_DAYS = 14;
const int MIN_TRIP_DAYS = 1;

// Cache
const int CACHE_DURATION_MINUTES = 30;
```

### Optional: Flutter .env (using flutter_dotenv)

If you prefer using .env files in Flutter:

1. Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_dotenv: ^5.1.0

flutter:
  assets:
    - .env
```

2. Create `tripcraft_app/.env`:
```env
API_BASE_URL=http://localhost:8000/api/v1
```

3. Create `tripcraft_app/.env.example`:
```env
API_BASE_URL=https://your-api.example.com/api/v1
```

---

## 5. Generate JWT Secret

Run in terminal:

```bash
# Option 1: Using OpenSSL
openssl rand -hex 64

# Option 2: Using Python
python -c "import secrets; print(secrets.token_hex(64))"

# Option 3: Using PowerShell (Windows)
[System.Convert]::ToBase64String((1..64 | ForEach-Object { Get-Random -Maximum 256 }))
```

Copy the output and paste as `JWT_SECRET` in your backend `.env` file.

---

## 6. Get Groq API Key

1. Go to [https://console.groq.com](https://console.groq.com)
2. Sign up or log in
3. Navigate to **API Keys**
4. Click **"Create API Key"**
5. Name it `tripcraft-dev` or similar
6. Copy the key (starts with `gsk_...`)
7. Add to backend `.env` as `GROQ_API_KEY`

---

## 7. Verify Setup Checklist

- [ ] Supabase project created
- [ ] Database schema deployed (all tables created)
- [ ] Storage bucket `trip-pdfs` created
- [ ] Backend `.env` file created with all variables
- [ ] Frontend `constants.dart` created
- [ ] JWT secret generated
- [ ] Groq API key obtained
- [ ] `.env.example` files created for both backend and frontend
- [ ] `.env` added to `.gitignore`

---

## 8. Database Connection Test

After setting up, test the connection:

```bash
# Using psql
psql postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres

# In psql, run:
\dt  # List all tables

# Expected output:
# users, trips, days, activities, notes, budget_items
```

---

## 9. Security Best Practices

### ⚠️ IMPORTANT:
- **NEVER commit `.env` files to Git**
- **NEVER expose `SUPABASE_SERVICE_KEY` in frontend code**
- Use `SUPABASE_ANON_KEY` in frontend (if using Supabase client directly)
- Rotate keys periodically
- Use different keys for dev/staging/production

### Add to `.gitignore`:
```
.env
.env.local
.env.*.local
*.key
secrets/
```

---

## 10. Next Steps

After completing this setup:

1. ✅ **Task 20 Complete** - Environment configured
2. ➡️ **Start Task 1** - Create Flutter project scaffold
3. ➡️ **Start Task 13** - Create FastAPI backend scaffold

---

## Troubleshooting

### Connection Issues:
- Verify `DATABASE_URL` has correct password
- Check Supabase project is not paused (free tier pauses after inactivity)
- Ensure your IP is whitelisted (Settings → Database → Connection Pooling)

### Storage Issues:
- Verify bucket name matches in code
- Check bucket is public if using signed URLs
- Ensure service role key has storage permissions

### API Key Issues:
- Groq keys start with `gsk_`
- Check key is active in Groq console
- Verify no extra spaces in `.env` file

---

**Setup Date**: November 21, 2025
**Status**: Ready for Development ✅
