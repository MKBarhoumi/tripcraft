# TripCraft Backend

FastAPI backend for the TripCraft mobile application.

## Features

- 🔐 JWT Authentication (register, login)
- 🗺️ Trip CRUD operations
- 🤖 AI-powered itinerary generation (Groq/Mixtral)
- 💬 Chat-based trip refinement
- 🔄 Bidirectional sync with conflict resolution
- 📄 PDF export via Supabase Storage
- 📊 Budget tracking
- 📝 Notes and activity management

## Tech Stack

- **Framework**: FastAPI 0.109.0
- **Database**: PostgreSQL (via Supabase) with SQLModel ORM
- **Migrations**: Alembic 1.13.1
- **Authentication**: JWT with python-jose and passlib
- **AI**: Groq API (Mixtral-8x7b-32768)
- **PDF**: ReportLab 4.0.9
- **Storage**: Supabase Storage
- **Testing**: Pytest with async support

## Setup

### 1. Install Dependencies

```bash
cd tripcraft-backend
pip install -r requirements.txt
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Required environment variables:
- `DATABASE_URL`: PostgreSQL connection string from Supabase
- `SECRET_KEY`: Generate with `openssl rand -hex 32`
- `GROQ_API_KEY`: Get from https://console.groq.com
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_KEY`: Your Supabase anon key
- `SUPABASE_BUCKET`: Storage bucket name (default: trip-exports)

### 3. Run Database Migrations

```bash
# Create initial migration
alembic revision --autogenerate -m "Initial schema"

# Apply migrations
alembic upgrade head
```

Or use the setup script:

```bash
python setup.py
```

### 4. Run the Server

```bash
# Development mode (with auto-reload)
uvicorn app.main:app --reload --port 8000

# Production mode
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

## API Documentation

Once the server is running, access:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### Authentication Endpoints

#### POST /api/auth/register
Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "John Doe"  // optional
}
```

**Response (201 Created):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "uuid-here",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2024-01-01T00:00:00"
  }
}
```

#### POST /api/auth/login
Login with email and password.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "uuid-here",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2024-01-01T00:00:00"
  }
}
```

#### GET /api/auth/me
Get current authenticated user information.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "id": "uuid-here",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2024-01-01T00:00:00"
}
```

#### DELETE /api/auth/me
Delete current user account (and all associated data).

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** 204 No Content

## Project Structure

```
tripcraft-backend/
├── app/
│   ├── core/           # Configuration, database, security
│   ├── models/         # SQLModel database models
│   ├── api/            # API route handlers
│   └── main.py         # FastAPI application
├── alembic/            # Database migrations
├── tests/              # Test suite
└── requirements.txt    # Python dependencies
```

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_models.py
```

## Database Models

- **User**: Authentication and user profiles
- **Trip**: Trip details with preferences
- **Day**: Daily itinerary structure
- **Activity**: Individual activities within days
- **Note**: User notes on trips
- **BudgetItem**: Budget tracking items

All models include sync fields for offline-first mobile app:
- `server_id`: UUID for server-side tracking
- `is_synced`: Sync status flag
- `local_updated_at`: Timestamp for conflict resolution

## Implementation Status

- [x] Authentication endpoints (BE-2) ✅
- [x] Trip CRUD endpoints (BE-3) ✅
- [x] AI itinerary generation (BE-4) ✅
- [x] Chat refinement (BE-5) ✅
- [x] Sync endpoints (BE-6) ✅
- [x] PDF export (BE-7) ✅

**All backend features complete! 🎉**

## License

Private project for educational purposes.
