# 🔧 Quick Reference - Environment Variables

## Backend Environment Variables (.env)

### Required Variables

| Variable | Description | Example | How to Get |
|----------|-------------|---------|------------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:pass@db.xyz.supabase.co:5432/postgres` | Supabase → Settings → Database |
| `SUPABASE_URL` | Your Supabase project URL | `https://xyz.supabase.co` | Supabase → Settings → API |
| `SUPABASE_SERVICE_KEY` | Service role key (secret!) | `eyJ...` | Supabase → Settings → API → service_role |
| `JWT_SECRET` | Secret for signing JWT tokens | `64-char hex string` | Generate: `openssl rand -hex 64` |
| `GROQ_API_KEY` | Groq API key for LLM | `gsk_...` | [console.groq.com](https://console.groq.com) |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_ALGORITHM` | `HS256` | Algorithm for JWT signing |
| `JWT_EXPIRATION_HOURS` | `24` | Token validity period |
| `PDF_TEMP_PATH` | `/tmp` | Temporary path for PDF generation |
| `PDF_STORAGE_BUCKET` | `trip-pdfs` | Supabase storage bucket name |
| `RATE_LIMIT_GENERATE_PER_DAY` | `30` | Max AI generations per user/day |
| `RATE_LIMIT_REFINE_PER_DAY` | `100` | Max refinements per user/day |
| `PORT` | `8000` | Server port |
| `ENVIRONMENT` | `development` | `development`, `staging`, or `production` |
| `DEBUG` | `true` | Enable debug mode |

---

## Frontend Constants (lib/src/constants.dart)

```dart
// API Configuration
const String API_BASE_URL = 'http://localhost:8000/api/v1'; // Development
// const String API_BASE_URL = 'https://your-api.railway.app/api/v1'; // Production

// Local Storage
const String HIVE_BOX_TRIPS = 'trips_box';
const String JWT_KEY = 'jwt_token';
const String USER_KEY = 'user_data';

// Timeouts & Limits
const int API_TIMEOUT_SECONDS = 15;
const int MAX_RETRY_ATTEMPTS = 3;
const int MAX_TRIP_DAYS = 14;
```

---

## 🔐 Security Checklist

- [ ] `.env` file is in `.gitignore`
- [ ] Never commit `.env` to Git
- [ ] Never expose `SUPABASE_SERVICE_KEY` in frontend
- [ ] Use `SUPABASE_ANON_KEY` in frontend (if needed)
- [ ] JWT_SECRET is random and secure (64+ chars)
- [ ] Different keys for dev/staging/production
- [ ] Database password is strong (20+ chars)

---

## 🚀 Quick Commands

### Generate JWT Secret
```bash
# Using OpenSSL (Mac/Linux)
openssl rand -hex 64

# Using Python
python -c "import secrets; print(secrets.token_hex(64))"

# Using PowerShell (Windows)
python -c "import secrets; print(secrets.token_hex(64))"
```

### Test Database Connection
```bash
# Using psql
psql "postgresql://postgres:PASSWORD@db.PROJECT-REF.supabase.co:5432/postgres"

# Test query
\dt  # List tables
```

### Validate Environment Setup
```bash
python setup_env.py
# Choose option 2: Validate existing .env file
```

---

## 📦 Environment File Locations

```
final_project/
├── .env.example                    # Template (commit this)
├── tripcraft-backend/.env          # Backend config (DO NOT commit)
└── tripcraft_app/lib/src/constants.dart  # Frontend config
```

---

## 🌐 API Endpoints Reference

Once backend is running, these will be available:

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login and get JWT
- `GET /api/v1/auth/me` - Get current user

### AI Generation
- `POST /api/v1/generate` - Generate trip itinerary
- `POST /api/v1/generate/refine` - Refine existing itinerary
- `POST /api/v1/summarize/day` - Summarize a day

### Trips CRUD
- `GET /api/v1/trips` - List user's trips
- `POST /api/v1/trips` - Create trip
- `GET /api/v1/trips/{id}` - Get trip details
- `PUT /api/v1/trips/{id}` - Update trip
- `DELETE /api/v1/trips/{id}` - Delete trip
- `POST /api/v1/trips/{id}/duplicate` - Duplicate trip

### Export
- `POST /api/v1/trips/{id}/export` - Export trip to PDF

---

## 🔗 Useful Links

- **Supabase Dashboard**: [app.supabase.com](https://app.supabase.com)
- **Groq Console**: [console.groq.com](https://console.groq.com)
- **Flutter Docs**: [docs.flutter.dev](https://docs.flutter.dev)
- **FastAPI Docs**: [fastapi.tiangolo.com](https://fastapi.tiangolo.com)

---

## ❓ Troubleshooting

### "Connection refused" to database
- Check `DATABASE_URL` has correct password
- Verify Supabase project is active (not paused)
- Check your IP is whitelisted in Supabase

### "Invalid JWT"
- Ensure `JWT_SECRET` is the same in all backend instances
- Check token hasn't expired (default 24 hours)
- Verify `JWT_ALGORITHM` matches (`HS256`)

### "Groq API error"
- Verify `GROQ_API_KEY` starts with `gsk_`
- Check key is active in Groq console
- Ensure no extra spaces in `.env` file

### "Storage bucket not found"
- Create bucket `trip-pdfs` in Supabase Storage
- Verify bucket name matches `PDF_STORAGE_BUCKET`
- Check bucket is public for signed URLs

---

**Quick Setup**: Run `python setup_env.py` and follow the prompts!
