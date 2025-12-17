# 🚀 TripCraft - Complete Setup Guide

This guide will help you clone and run the TripCraft project from GitHub.

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

1. **Git** - [Download here](https://git-scm.com/download)
   ```bash
   git --version  # Verify installation
   ```

2. **Flutter SDK (3.0+)** - [Installation Guide](https://docs.flutter.dev/get-started/install)
   ```bash
   flutter --version
   flutter doctor  # Check for any issues
   ```

3. **Python (3.11+)** - [Download here](https://www.python.org/downloads/)
   ```bash
   python --version
   ```

4. **Android Studio or VS Code** - For mobile development
   - [Android Studio](https://developer.android.com/studio)
   - [VS Code](https://code.visualstudio.com/) with Flutter extension

### Required Accounts

1. **Supabase Account** - [Sign up here](https://supabase.com)
2. **Groq API Account** - [Sign up here](https://console.groq.com)

---

## 📥 Step 1: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/tripcraft.git

# Navigate to the project directory
cd tripcraft
```

---

## 🗄️ Step 2: Supabase Setup

### 2.1 Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Click "New Project"
3. Fill in the details:
   - **Name**: TripCraft
   - **Database Password**: Save this securely!
   - **Region**: Choose closest to you
4. Wait for project to be ready (~2 minutes)

### 2.2 Get Your Credentials

1. Go to **Project Settings** → **API**
2. Note down:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)
   - **service_role key** (starts with `eyJ...`)

### 2.3 Run Database Migrations

1. Go to **SQL Editor** in Supabase Dashboard
2. Open the file: `SUPABASE_SETUP.md` in this repository
3. Copy the SQL schema from that file
4. Paste and run in SQL Editor

### 2.4 Create Storage Bucket

1. Go to **Storage** → **New Bucket**
2. Create bucket named: `trip-pdfs`
3. Set to **Public** (for PDF downloads)

---

## 🔧 Step 3: Backend Setup

### 3.1 Install Python Dependencies

```bash
cd tripcraft-backend
pip install -r requirements.txt
```

### 3.2 Configure Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your actual credentials
```

Open `tripcraft-backend/.env` and fill in:

```env
# Database (from Supabase)
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@db.xxxxx.supabase.co:5432/postgres

# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here

# JWT Secret (generate a random string)
JWT_SECRET=your-random-secret-here-use-openssl-rand-hex-64
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

# Groq API (get from console.groq.com)
GROQ_API_KEY=gsk_your-groq-api-key-here
GROQ_MODEL=mixtral-8x7b-32768
```

**Generate JWT Secret:**
```bash
# On Windows (PowerShell)
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})

# On Mac/Linux
openssl rand -hex 64
```

### 3.3 Start the Backend Server

```bash
# Make sure you're in tripcraft-backend directory
uvicorn app.main:app --reload
```

The backend will run at: **http://localhost:8000**

Test it by visiting: **http://localhost:8000/docs** (API documentation)

---

## 📱 Step 4: Frontend Setup

### 4.1 Install Flutter Dependencies

```bash
# Navigate to Flutter app directory
cd tripcraft_app

# Get dependencies
flutter pub get
```

### 4.2 Configure Environment Variables

```bash
# Copy the example file
cp .env.example .env
```

Open `tripcraft_app/.env` and fill in:

```env
# Backend API URL
API_BASE_URL=http://localhost:8000

# Supabase (for PDF downloads)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 4.3 Run the App

```bash
# Check connected devices
flutter devices

# Run on your device/emulator
flutter run
```

**For specific platforms:**
```bash
flutter run -d chrome        # Web browser
flutter run -d windows       # Windows desktop
flutter run -d android       # Android device/emulator
flutter run -d ios           # iOS device/simulator (Mac only)
```

---

## ✅ Step 5: Verify Everything Works

### Test Backend

1. Open http://localhost:8000/docs
2. Try the `/api/auth/register` endpoint:
   ```json
   {
     "email": "test@example.com",
     "password": "Test123!",
     "full_name": "Test User"
   }
   ```

### Test Frontend

1. Launch the app
2. Register a new account
3. Create a test trip
4. Generate an itinerary using AI

---

## 🐛 Troubleshooting

### Backend Issues

**Problem**: "ModuleNotFoundError"
```bash
# Solution: Reinstall dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

**Problem**: "Database connection failed"
- Check your DATABASE_URL in `.env`
- Verify Supabase project is running
- Check database password is correct

**Problem**: "Groq API error"
- Verify your GROQ_API_KEY is correct
- Check you have API credits remaining

### Frontend Issues

**Problem**: "Flutter not found"
```bash
# Solution: Add Flutter to PATH
# Follow: https://docs.flutter.dev/get-started/install
```

**Problem**: "Package not found"
```bash
flutter clean
flutter pub get
```

**Problem**: "Can't connect to backend"
- Ensure backend is running on port 8000
- Check `API_BASE_URL` in `tripcraft_app/.env`
- Try http://10.0.2.2:8000 for Android emulator

---

## 🎯 Quick Start Commands

### Start Backend
```bash
cd tripcraft-backend
uvicorn app.main:app --reload
```

### Start Frontend
```bash
cd tripcraft_app
flutter run
```

---

## 📚 Additional Resources

- **API Documentation**: http://localhost:8000/docs (when backend is running)
- **Supabase Docs**: https://supabase.com/docs
- **Flutter Docs**: https://docs.flutter.dev
- **Groq API Docs**: https://console.groq.com/docs

---

## 🔐 Security Reminders

- ⚠️ **NEVER** commit `.env` files to Git
- ⚠️ Keep your API keys secret
- ⚠️ Don't share your database password
- ⚠️ Use environment variables for all secrets

---

## 🤝 Need Help?

If you encounter issues:

1. Check the troubleshooting section above
2. Review error messages carefully
3. Ensure all prerequisites are installed
4. Verify all environment variables are set correctly

---

## 📄 Project Structure

```
tripcraft/
├── tripcraft_app/           # Flutter mobile app
│   ├── lib/src/            # Source code
│   ├── test/               # Tests
│   └── .env                # Frontend environment (create from .env.example)
│
├── tripcraft-backend/      # FastAPI backend
│   ├── app/                # Application code
│   ├── tests/              # Tests
│   └── .env                # Backend environment (create from .env.example)
│
├── SETUP_GUIDE.md          # This file
├── SUPABASE_SETUP.md       # Database schema
└── README.md               # Project overview
```

---

**Happy Coding! 🚀**
