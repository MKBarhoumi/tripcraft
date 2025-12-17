# Quick Start Guide - Task BE-7 Complete

## Installation

```bash
cd tripcraft-backend

# Install all dependencies (including new PDF and Storage packages)
pip install -r requirements.txt
```

## Configuration

Ensure your `.env` file has these variables:

```env
# Required
DATABASE_URL=sqlite:///./tripcraft.db
SECRET_KEY=your-secret-key
GROQ_API_KEY=your-groq-api-key

# Optional (for cloud PDF storage)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key
SUPABASE_BUCKET=trip-exports
```

## Running the Server

```bash
# Start the FastAPI server
uvicorn app.main:app --reload --port 8000
```

The API will be available at: http://localhost:8000

## Testing the Export Endpoint

### Option 1: Using Swagger UI

1. Open http://localhost:8000/docs
2. Authenticate:
   - POST /api/auth/register or /api/auth/login
   - Click "Authorize" button, enter token
3. Create a trip:
   - POST /api/trips (or POST /api/generate for AI generation)
4. Export the trip:
   - POST /api/trips/{trip_id}/export
   - Check the response for `download_url` or `pdf_base64`

### Option 2: Using Python

```python
import requests
import base64

# 1. Login
response = requests.post("http://localhost:8000/api/auth/login", json={
    "email": "test@example.com",
    "password": "password"
})
token = response.json()["access_token"]

# 2. Create a trip (or use existing trip_id)
response = requests.post(
    "http://localhost:8000/api/trips",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "destination": "Paris, France",
        "start_date": "2024-06-01",
        "end_date": "2024-06-03",
        "budget_amount": 2000.0
    }
)
trip_id = response.json()["id"]

# 3. Export the trip
response = requests.post(
    f"http://localhost:8000/api/trips/{trip_id}/export",
    headers={"Authorization": f"Bearer {token}"}
)

data = response.json()

if data["download_url"]:
    print(f"Download PDF: {data['download_url']}")
else:
    # Save base64 PDF
    pdf_bytes = base64.b64decode(data["pdf_base64"])
    with open(data["filename"], "wb") as f:
        f.write(pdf_bytes)
    print(f"PDF saved as {data['filename']}")
```

### Option 3: Using cURL

```bash
# 1. Login
TOKEN=$(curl -s -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}' \
  | jq -r '.access_token')

# 2. Export trip (replace 1 with your trip ID)
curl -X POST "http://localhost:8000/api/trips/1/export" \
  -H "Authorization: Bearer $TOKEN" \
  -o trip_export.json

# 3. Download PDF (if Supabase configured)
DOWNLOAD_URL=$(jq -r '.download_url' trip_export.json)
curl -o trip.pdf "$DOWNLOAD_URL"

# Or decode base64 (if no Supabase)
jq -r '.pdf_base64' trip_export.json | base64 -d > trip.pdf
```

## Running Tests

```bash
# Run all export tests
pytest tests/test_export.py -v

# Run all backend tests
pytest -v

# Run with coverage
pytest --cov=app --cov-report=html
```

## Verifying Installation

```bash
# Check Python packages
python -c "import reportlab; import supabase; print('✅ All packages installed')"

# Check FastAPI app loads
python -c "from app.main import app; print('✅ FastAPI app loads successfully')"

# List all routes
python -c "from app.main import app; print('\n'.join([f'{r.path}' for r in app.routes]))"
```

## Troubleshooting

### ReportLab Not Installed

```bash
pip install reportlab==4.0.9
```

### Supabase Not Installed

```bash
pip install supabase==2.10.0
```

### Import Errors

Make sure you're in the correct directory:
```bash
cd tripcraft-backend
python -m pytest  # Use python -m to ensure proper path resolution
```

### Server Won't Start

Check for syntax errors:
```bash
python -m py_compile app/main.py
python -m py_compile app/api/export.py
```

## API Endpoints Summary

### Export
- **POST /api/trips/{trip_id}/export** - Generate and download PDF

### Authentication
- **POST /api/auth/register** - Create account
- **POST /api/auth/login** - Get access token
- **GET /api/auth/me** - Get current user

### Trips
- **POST /api/trips** - Create trip
- **GET /api/trips** - List trips
- **GET /api/trips/{id}** - Get trip details
- **PUT /api/trips/{id}** - Update trip
- **DELETE /api/trips/{id}** - Delete trip

### AI Generation
- **POST /api/generate** - Generate itinerary with AI

### Chat Refinement
- **POST /api/chat** - Refine trip with natural language
- **GET /api/chat/suggestions/{trip_id}** - Get contextual suggestions

### Sync
- **POST /api/sync** - Bidirectional sync

## Documentation

- **[EXPORT_API_GUIDE.md](./EXPORT_API_GUIDE.md)** - Complete PDF export documentation
- **[GENERATION_API_GUIDE.md](./GENERATION_API_GUIDE.md)** - AI generation documentation
- **[CHAT_REFINEMENT_API_GUIDE.md](./CHAT_REFINEMENT_API_GUIDE.md)** - Chat refinement documentation
- **[SYNC_API_GUIDE.md](./SYNC_API_GUIDE.md)** - Sync endpoint documentation
- **[README.md](./README.md)** - Main backend documentation

## Next Steps

1. ✅ Install dependencies: `pip install -r requirements.txt`
2. ✅ Configure environment: Edit `.env` file
3. ✅ Run migrations: `alembic upgrade head`
4. ✅ Start server: `uvicorn app.main:app --reload`
5. ✅ Test export: Visit http://localhost:8000/docs
6. ✅ Integrate in Flutter app

## Status

✅ **All 7 backend tasks complete (100%)**  
✅ **All 20 project tasks complete (100%)**  
✅ **Production ready!**

---

For detailed documentation, see [EXPORT_API_GUIDE.md](./EXPORT_API_GUIDE.md).
