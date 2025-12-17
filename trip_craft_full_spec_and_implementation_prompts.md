# TripCraft — Complete Specification & Implementation Prompts

> **Goal:** One ready-to-run Markdown file that another AI/developer can use to build TripCraft. The document starts with the **Frontend** (complete) and then the Backend, DB, LLM, export flow, deployment, tests and CI. This file was produced from the two PDFs you uploaded (TripCraft end final, TripCraft IMP).

---

## Table of Contents

1. Summary
2. Important environment variables
3. Frontend (Full) — **Start here**
   - FE-1 Project scaffold & dependencies
   - FE-2 Data models (Dart) + JSON serialization
   - FE-3 Local storage service (Hive JSON)
   - FE-4 API client (Dio) + auth token storage
   - FE-5 Riverpod providers: auth, trip, sync
   - FE-6 UI skeleton & routes (screens)
   - FE-7 Generate flow & progress UI
   - FE-8 Trip Editor (full editing UX)
   - FE-9 Chat Refine UI & integration
   - FE-10 Export & PDF viewing
   - FE-11 Offline sync service + conflict handling
   - FE-12 Frontend tests & CI
4. Backend (FastAPI) — full implementation prompts
   - BE-1 Backend scaffold & DB models + migrations
   - BE-2 Authentication & security (JWT + hashing)
   - BE-3 LLM integration (Groq) and /generate endpoints
   - BE-4 Export PDF flow & Supabase upload
   - BE-5 Rate-limiting & caching
   - BE-6 Embeddings & semantic search (optional)
   - BE-7 Tests, CI/CD & deployment
5. Database schema (SQL / ERD)
6. LLM prompt templates & validation rules
7. Sample JSONs (requests, LLM responses, saved trip)
8. Deployment, Docker, CI/CD notes
9. Checklist & recommended next steps

---

# 1. Summary

TripCraft is a Flutter mobile app (Riverpod + Hive local JSON) with a FastAPI backend, Postgres (Supabase), Supabase Storage for PDFs and Groq.ai LLM for itinerary generation.

High-level features:
- Generate 1/3/5-day itineraries via LLM based on destination, dates, travel style, budget.
- Chat-style refinement flow to tweak draft itineraries.
- Full trip editor with days, activities, budgets, notes.
- Offline-first: local Hive storage + sync service with server.
- Export trip to PDF via backend HTML->PDF and Supabase upload.

The remainder of this file is organized so you can hand it to another AI/developer to implement each step. **Begin with the Frontend (FE-1 → FE-12) and complete it fully before proceeding to backend tasks.**

---

# 2. Environment variables (quick)

**Backend (.env)**
```
DATABASE_URL=postgresql://user:pass@host:5432/dbname
GROQ_API_KEY=sk-...
JWT_SECRET=<random hex>
JWT_ALGORITHM=HS256
SUPABASE_URL=https://xyz.supabase.co
SUPABASE_SERVICE_KEY=<service-role-key>
PDF_TEMP_PATH=/tmp
PGVECTOR_ENABLED=false
RATE_LIMIT_GENERATE_PER_DAY=30
RATE_LIMIT_REFINE_PER_DAY=100
```

**Frontend (constants or .env)**
```
API_BASE_URL=https://api.yourdomain.com/api/v1
```

---

# 3. Frontend (Full)

> **Instruction:** Implement the entire frontend first. Every FE step below is a deliverable with an explicit prompt you can paste to an implementation LLM or give to a developer.

## FE-1 — Project scaffold & dependencies

**Deliverable / checklist**
- Create a Flutter project named `tripcraft_app/` with the file tree described below.
- `pubspec.yaml` must include the precise dependency versions.
- `lib/src/main.dart` and `lib/src/app.dart` should initialize Hive and wrap `ProviderScope`.
- Use JSON-in-Hive (no binary adapters) for now.
- Produce a runnable placeholder Home screen.

**File tree (final)**
```
tripcraft_app/
  android/
  ios/
  lib/
    main.dart
    src/
      app.dart
      constants.dart
      routes.dart
      utils/
        validators.dart
        formatters.dart
      services/
        api_client.dart
        auth_service.dart
        local_storage_service.dart
        sync_service.dart
      providers/
        auth_provider.dart
        trip_provider.dart
        sync_provider.dart
      models/
        user.dart
        trip.dart
        day.dart
        activity.dart
        note.dart
        budget_item.dart
      screens/
        auth/
          login_screen.dart
          register_screen.dart
        home/
          home_screen.dart
          trip_list_screen.dart
          trip_detail_screen.dart
        trip/
          create_trip_screen.dart
          generate_progress_screen.dart
          trip_editor_screen.dart
          chat_refine_screen.dart
          export_screen.dart
      widgets/
        trip_card.dart
        day_card.dart
        activity_card.dart
        budget_row.dart
        loading_overlay.dart
      hive_adapters/
        (if using adapters)
  pubspec.yaml
```

**pubspec.yaml (key deps)**
```yaml
environment:
  sdk: ">=2.18.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.0.3
  go_router: ^6.2.0
  dio: ^5.2.1
  flutter_secure_storage: ^8.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  freezed_annotation: ^2.2.0
  json_annotation: ^4.8.0
  intl: ^0.18.0
  url_launcher: ^6.1.7
  pdfx: ^3.0.0
  uuid: ^3.0.6

dev_dependencies:
  build_runner: ^2.3.3
  freezed: ^2.3.2
  json_serializable: ^6.6.1
```

**Prompt to run (developer/LLM)**
```
Act as a senior Flutter developer. Create a full starter Flutter project named tripcraft_app implementing the TripCraft file tree. Use the exact dependency versions above. Implement Hive initialization and openBox(HIVE_BOX_TRIPS) using JSON storage. Add lib/src/constants.dart with API_BASE_URL and keys. Provide flutter run instructions and a zip/gitrepo layout.
```

---

## FE-2 — Data models (Dart) + JSON serialization

**Deliverable**
- Implement Dart models: `Trip`, `Day`, `Activity`, `Note`, `BudgetItem`.
- Each model: constructor using `Uuid()` for id default, `fromJson`, `toJson`.
- Add `serverId`, `isSynced`, `localUpdatedAt` to `Trip`.
- Add a unit test verifying round-trip serialization.

**Sample model: Activity (use as template for others)**
```dart
import 'package:uuid/uuid.dart';

class Activity {
  final String id;
  String title;
  String? startTime; // 'HH:MM'
  String? endTime;
  String? location;
  String? details;
  double estimatedCost;

  Activity({
    String? id,
    required this.title,
    this.startTime,
    this.endTime,
    this.location,
    this.details,
    this.estimatedCost = 0.0,
  }) : id = id ?? Uuid().v4();

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
    id: j['id'] ?? Uuid().v4(),
    title: j['title'],
    startTime: j['start_time'],
    endTime: j['end_time'],
    location: j['location'],
    details: j['details'],
    estimatedCost: (j['estimated_cost'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start_time': startTime,
    'end_time': endTime,
    'location': location,
    'details': details,
    'estimated_cost': estimatedCost,
  };
}
```

**Prompt (LLM)**
```
Implement the Dart model classes Trip, Day, Activity, Note, BudgetItem per spec. Provide full Dart source for each file and a small unit test that asserts Trip.fromJson(trip.toJson()) == trip. Include serverId, isSynced, localUpdatedAt fields.
```

---

## FE-3 — Local storage service (Hive JSON approach)

**Deliverable**
- `lib/src/services/local_storage_service.dart` using Hive storing JSON maps in `trips_box`.
- Methods: `init()`, `getAllTrips()`, `saveTrip(Trip)`, `saveTrips(List<Trip>)`, `deleteTrip(String id)`.
- Provide a Riverpod provider `localStorageServiceProvider` and show example initialization in `main.dart`.

**Sample usage (main.dart init)**
```dart
await Hive.initFlutter();
await Hive.openBox(HIVE_BOX_TRIPS);
await ref.read(localStorageServiceProvider).init();
```

**Prompt (LLM)**
```
Create LocalStorageService (Hive) that stores Trip JSON maps in box 'trips_box'. Implement init(), getAllTrips(), saveTrip(), saveTrips(), deleteTrip(). Provide Riverpod provider wiring and example initialization in main.dart.
```

---

## FE-4 — API client (Dio) + auth token storage

**Deliverable**
- `lib/src/services/api_client.dart` per spec: baseUrl constant, timeouts, interceptor attaching JWT from `flutter_secure_storage`, Accept header, retry logic on 429 (exponential backoff).
- Methods: `login`, `register`, `generateItinerary`, `refineItinerary`, `createTrip`, `listTrips`, `duplicateTrip`, `exportTrip`, `getTrip`, `updateTrip`, `deleteTrip`.

**Sample ApiClient (excerpt)**
```dart
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  ApiClient({String baseUrl = API_BASE_URL})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: 15000, receiveTimeout: 15000)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: JWT_KEY);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },
      onError: (DioError e, handler) {
        // Retry logic for 429
        return handler.next(e);
      },
    ));
  }
  // ... methods: login, register, generateItinerary, ...
}
```

**Prompt (LLM)**
```
Implement ApiClient using Dio with exact methods. Add interceptor reading JWT_KEY from flutter_secure_storage and attaching Authorization header. Implement exponential backoff retry for 429 up to 3 attempts. Provide unit tests that mock Dio to verify header behavior.
```

---

## FE-5 — Riverpod providers: auth, trip, sync

**Deliverable**
- `auth_provider.dart`: `AuthNotifier` storing JWT in secure storage and exposing `AuthState`.
- `trip_provider.dart`: `TripListNotifier` with `loadLocalTrips`, `fetchFromServer`, `addTrip`.
- `sync_provider.dart`: exposes `syncAll()` implementing sync algorithm.

**Auth provider (summary)**
- On login: call `ApiClient.login`, store token in `FlutterSecureStorage`, update state.
- On logout: delete token.

**Trip provider (summary)**
- Load from local storage, fetch server trips, update local cache.
- Add trip: save locally and mark `isSynced=false` until pushed.

**Prompt (LLM)**
```
Implement Riverpod providers per spec: authProvider, tripListProvider, and syncProvider. Add unit tests with mocked ApiClient and LocalStorageService to demonstrate expected state transitions.
```

---

## FE-6 — UI skeleton & routes (screens)

**Deliverable**
- Implement screens and shared widgets (skeletons with working navigation via `go_router`):
  - `LoginScreen`, `RegisterScreen`.
  - `HomeScreen`, `TripListScreen`, `TripDetailScreen`.
  - `CreateTripScreen`, `GenerateProgressScreen`, `TripEditorScreen`, `ChatRefineScreen`, `ExportScreen`.
  - Widgets: `trip_card`, `day_card`, `activity_card`, `loading_overlay`.

**Prompt (LLM)**
```
Build the UI skeleton using go_router. For each screen implement layout and state hookups. Return Dart code for all screens and widgets (stateful/consumer as needed). Ensure navigation works.
```

---

## FE-7 — Generate flow & progress UI

**Deliverable**
- CreateTrip form → POST `/generate` payload.
- Navigate to `GenerateProgressScreen` showing spinner and incremental messages.
- On success open `TripEditor` with draft JSON.

**Behavior & UX**
- Show messages: "Contacting AI...", "Creating day 1...".
- Support cancel and timeout. Provide retry button on errors (502/429).

**Prompt (LLM)**
```
Implement the Generate flow: submit CreateTrip payload to /generate, show progress UI, handle timeouts and cancellations, and navigate to TripEditor with draft on success. Show user-friendly messages on LLM errors.
```

---

## FE-8 — Trip Editor (full editing UX)

**Deliverable**
- Expandable `DayCard` list with `ActivityCard` items.
- Inline edit; add/remove activities, times, budgets, notes.
- Save persists to Hive and sets `isSynced=false` and updates `localUpdatedAt`.
- Bulk actions: duplicate trip, add day, reorder activities (optional drag/drop).
- Undo snackbars on delete.

**Prompt (LLM)**
```
Implement TripEditorScreen with full editing UX. Include save logic that updates local Hive and toggles isSynced=false and localUpdatedAt. Implement duplicate trip action and undo for deletions.
```

---

## FE-9 — Chat Refine UI & integration

**Deliverable**
- Chat-style interface sending `{ draft, instruction }` to `/generate/refine`.
- Replace current draft in the editor after validation.
- Store refine prompt history locally.
- Optionally show diff highlighting before/after.

**Prompt (LLM)**
```
Implement ChatRefineScreen. On send, POST /generate/refine with current draft and instruction. Validate returned JSON and replace draft. Preserve refine history. Provide simple UI diff highlighting.
```

---

## FE-10 — Export & PDF viewing

**Deliverable**
- `ExportScreen` calls `POST /trips/{id}/export` and opens returned URL in `pdfx` or external browser.
- Show progress and retry on failure; provide a share button.

**Prompt (LLM)**
```
Implement ExportScreen: call ApiClient.exportTrip(tripId), show progress, and open returned URL in in-app PDF viewer (pdfx) or with url_launcher. Add share link button.
```

---

## FE-11 — Offline sync service + conflict handling

**Deliverable**
- `SyncService` triggers on app start, connectivity change, or manual sync.
- Conflict model: last-write-wins by default; optionally prompt user when server has newer data.
- Sync algorithm (pseudocode):
  1. For each unsynced trip:
     - If `serverId == null`: POST /trips, update `serverId`, `isSynced=true`.
     - Else GET /trips/{serverId}, compare `updated_at` and `localUpdatedAt`.
     - If local newer: PUT /trips/{serverId}.
     - If server newer: record conflict (optionally prompt user or accept server depending on UI choice).

**Prompt (LLM)**
```
Implement SyncService per spec. Provide code that iterates unsynced trips, posts new ones, updates existing, compares updated timestamps, and returns a sync report. Wire it to connectivity changes and provide a manual sync UI action.
```

---

## FE-12 — Frontend tests & CI

**Deliverable**
- Unit tests for models (serialization), `LocalStorageService`, `ApiClient` header behavior.
- Widget tests for `LoginScreen` and `TripListScreen`.
- GitHub Actions workflow `.github/workflows/flutter.yml` running `flutter analyze` and `flutter test`.

**Prompt (LLM)**
```
Add unit tests and widget tests per spec and create GitHub Actions workflow that runs flutter analyze and flutter test on push to main.
```

---

# 4. Backend (FastAPI) — full implementation prompts

> After frontend is fully implemented and tested locally, implement the backend using the BE prompts below.

## BE-1 — Backend scaffold (FastAPI) & DB models + migrations

**Deliverable**
- FastAPI project `tripcraft-backend` with the project layout and files described below.
- Use `SQLModel` models for `users`, `trips`, `days`, `activities`, `notes`, `budget_items`.
- Alembic migrations + `.env.example` and Dockerfile + docker-compose for Postgres.

**Dependencies (requirements.txt skeleton)**
```
fastapi
uvicorn[standard]
sqlmodel
asyncpg
alembic
python-jose[cryptography]
passlib[bcrypt]
httpx
python-dotenv
jinja2
pdfkit
pydantic
supabase
pgvector  # optional
slowapi   # optional
pytest
pytest-asyncio
```

**Project layout (final)**
```
tripcraft-backend/
  Dockerfile
  requirements.txt
  alembic/
  .env
  app/
    main.py
    core/
      config.py
      security.py
    db/
      session.py
      base.py
    models/
      user.py
      trip.py
      day.py
      activity.py
      note.py
      budget_item.py
    schemas/
      auth.py
      trip.py
    api/
      auth.py
      trips.py
      ai.py
      export.py
    services/
      llm_service.py
      export_service.py
      cache.py
      rate_limit.py
    templates/
      trip_template.html
    utils/
      validators.py
```

**Prompt (LLM)**
```
Act as a senior backend engineer. Create a FastAPI project tripcraft-backend matching the project layout. Implement SQLModel models mirroring the SQL in the spec. Provide alembic setup and example initial migration. Return Dockerfile and instructions to run locally with Postgres container.
```

---

## BE-2 — Authentication & security (JWT + password hashing)

**Deliverable**
- `app/core/security.py` with password hashing via `passlib` (bcrypt) and JWT encode/decode via `python-jose`.
- Routes: `/api/v1/auth/register`, `/api/v1/auth/login`, `/api/v1/auth/me`.

**Prompt (LLM)**
```
Implement security.py using passlib bcrypt and python-jose. Add auth routes and tests for register/login/token validation with expiry handling.
```

---

## BE-3 — LLM integration (Groq) and /generate endpoints

**Deliverable**
- `POST /api/v1/generate`, `POST /api/v1/generate/refine`, `POST /api/v1/summarize/day`.
- `services/llm_service.py` that posts to `https://api.groq.ai/v1/generate` with `GROQ_API_KEY`.
- Validate responses using Pydantic schemas and retry once if the output doesn't match JSON schema.

**LLM Validation policy**
- Validate using Pydantic models (`ActivityIn`, `DayIn`, `TripCreate` schema). If invalid, retry with a strict instruction "Output only JSON." If still invalid, return 502 with raw LLM output logged.

**Prompt template (example)**
```json
{ "destination": "{destination}", "days": {days}, "start_date": "{start_date}", "traveler_profile": {"travel_style":"{travel_style}", "budget_tier":"{budget_tier}", "preferences":"{preferences}"}, "response_schema": {...} }
```

**Prompt (LLM)**
```
Implement LLMService that posts to Groq, constructs structured prompt/response_schema, validates JSON with Pydantic, retries once on invalid output, and returns draft trip JSON. Provide unit tests mocking httpx responses.
```

---

## BE-4 — Export PDF flow & Supabase upload

**Deliverable**
- `POST /api/v1/trips/{id}/export`: render `templates/trip_template.html` via Jinja2, convert to PDF (wkhtmltopdf or WeasyPrint), upload to Supabase Storage using `SUPABASE_SERVICE_KEY` and return signed URL.

**Prompt (LLM)**
```
Implement export endpoint that renders Jinja2 HTML and converts to PDF, uploads to Supabase, and returns a signed URL. Add fallback for local dev to return file path.
```

---

## BE-5 — Rate-limiting & caching

**Deliverable**
- Per-user counters (MVP: in-memory; production: Redis) to enforce `RATE_LIMIT_GENERATE_PER_DAY` and `RATE_LIMIT_REFINE_PER_DAY`.
- In-memory LRU cache keyed by SHA256(payload + userId + model) to deduplicate identical generation requests.

**Prompt (LLM)**
```
Add rate-limiting (slowapi or custom) to /generate and /generate/refine using per-user counters. Add an LRU cache (in-memory) to return cached drafts for identical payloads keyed by SHA256(payload+userId+model).
```

---

## BE-6 — Embeddings & semantic search (optional)

**Deliverable**
- `/api/v1/embeddings` to compute embeddings (Groq or alternative) and store vectors in `pgvector` table.
- Search endpoint to query nearest neighbors for notes/trips.

**Prompt (LLM)**
```
Implement embeddings endpoint using Groq or alternative embedding model and store vectors in pgvector. Add a /search endpoint returning nearest neighbors.
```

---

## BE-7 — Tests, CI/CD & Deployment

**Deliverable**
- Unit and integration tests using `pytest` and `pytest-asyncio` covering auth, trips CRUD, generate/refine (mocked LLM), and export (mocked storage).
- GitHub Actions workflows to run tests and build images.
- Deployment guides for Railway / Render / Cloud Run + env var instructions.

**Prompt (LLM)**
```
Create tests and GitHub Actions CI that runs linters/tests and builds docker images, then provide deployment scripts for Railway/Render/Cloud Run with env var instructions including Supabase keys.
```

---

# 5. Database schema (SQL)

Use Supabase (Postgres) with UUIDs. Example statements:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE trips (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT,
  destination TEXT NOT NULL,
  start_date DATE,
  end_date DATE,
  travel_style TEXT,
  budget_tier TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE days (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id uuid NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  day_index INTEGER NOT NULL,
  date DATE,
  summary TEXT,
  total_day_budget NUMERIC DEFAULT 0
);

CREATE TABLE activities (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  day_id uuid NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  start_time TIME,
  end_time TIME,
  location TEXT,
  details TEXT,
  estimated_cost NUMERIC DEFAULT 0
);

CREATE TABLE notes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id uuid REFERENCES trips(id) ON DELETE CASCADE,
  day_id uuid REFERENCES days(id) ON DELETE CASCADE,
  content TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE budget_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id uuid REFERENCES trips(id) ON DELETE CASCADE,
  day_id uuid REFERENCES days(id) ON DELETE CASCADE,
  category TEXT,
  amount NUMERIC DEFAULT 0,
  description TEXT
);
```

(Optional pgvector table for embeddings.)

---

# 6. LLM prompt templates & validation rules

**System instruction** (send as top-level system message):
```
You are an expert travel planner. User input will be a JSON object. Always return a single JSON object that exactly matches the schema requested. Do not include any explanation, markdown, or text outside the JSON. Each activity must include title, optional start_time and end_time, location, details, estimated_cost. Always provide daily_budget and total_budget_estimate as numbers.
```

**Generation payload pattern**
```json
{
  "destination": "{destination}",
  "days": {days},
  "start_date": "{start_date}",
  "traveler_profile": {
    "travel_style": "{travel_style}",
    "budget_tier": "{budget_tier}",
    "preferences": "{preferences}"
  },
  "response_schema": {
    "trip_title":"string",
    "days":[{"day_index":"int","date":"YYYY-MM-DD","summary":"string","activities":[{"title":"string","start_time":"HH:MM|null","end_time":"HH:MM|null","location":"string","details":"string","estimated_cost":"number"}],"daily_budget":"number"}],
    "total_budget_estimate":"number",
    "local_tips":["string"]
  }
}
```

**Validation policy**
- Parse LLM response JSON and validate against Pydantic models. If invalid, retry once with explicit instruction: "Return only JSON; follow this schema exactly." If still invalid, return 502 with raw LLM output logged for debugging.

---

# 7. Sample JSONs

**Generate request (client -> backend)**
```json
{
  "destination": "Istanbul, Turkey",
  "days": 3,
  "start_date": "2026-03-12",
  "travel_style": "relaxed",
  "budget_tier": "mid",
  "preferences": "history, local food, walking tours"
}
```

**Example LLM response (backend -> client)**
```json
{
  "trip_title": "3-day Istanbul — history & food",
  "days": [
    {
      "day_index": 1,
      "date": "2026-03-12",
      "summary": "Sultanahmet highlights: Hagia Sophia, Blue Mosque, Turkish lunch.",
      "activities": [
        {"title":"Hagia Sophia","start_time":"09:00","end_time":"11:00","location":"Sultanahmet","details":"Visit the museum and learn the Byzantine history","estimated_cost":15},
        {"title":"Blue Mosque","start_time":"11:15","end_time":"12:00","location":"Sultanahmet","details":"Exterior and courtyard visit; dress respectfully","estimated_cost":0},
        {"title":"Local lunch: Kebab spot","start_time":"12:30","end_time":"13:30","location":"Sultanahmet","details":"Try lamb kebab and ayran","estimated_cost":12}
      ],
      "daily_budget": 60
    }
  ],
  "total_budget_estimate": 200,
  "local_tips": ["Carry small bills for vendors", "Buy museum combo pass to save money"]
}
```

**Saved trip JSON (local DB)**
```json
{
  "id": "uuid-1234",
  "title": "3-day Istanbul — history & food",
  "destination": "Istanbul, Turkey",
  "start_date": "2026-03-12",
  "travel_style": "relaxed",
  "budget_tier": "mid",
  "days": [ ... ],
  "is_synced": false,
  "server_id": null,
  "local_updated_at": "2025-11-21T20:15:00Z"
}
```

---

# 8. Deployment, Docker, CI/CD notes

**Backend Dockerfile (simple)**
```
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**CI/CD (outline)**
- Backend: run lint (ruff/black), unit tests, build Docker image, push to registry, deploy to Railway/Render/Cloud Run.
- Flutter: run `flutter analyze`, `flutter test`, build APK on push to `main`.

**Before coding checklist**
- Create Supabase project & get SERVICE_KEY
- Prepare `.env` for backend & frontend
- Configure secrets in CI

---

# 9. Checklist & recommended next steps (priority order)

1. Frontend scaffold & models (FE-1, FE-2) — get local dev environment working.
2. Backend scaffold & DB models (BE-1) — so endpoints can be stubbed.
3. API client + auth on frontend (FE-4, FE-5) — connect to backend auth stubs.
4. Generate endpoint + UI generate flow (BE-3, FE-7) — core app feature.
5. Trip editor & sync (FE-8, FE-11, BE-5) — offline-first flows.
6. Export PDF (BE-4, FE-10).
7. Refinement chat (BE-3 refine, FE-9).
8. Tests & CI (FE-12, BE-7).
9. Optional: Embeddings & semantic search (BE-6).

---

# Notes & sources

This Markdown has been assembled from your uploaded files `TripCraft end final.pdf` and `TripCraft IMP.pdf` and formatted as an implementation-ready spec + prompts. Use each FE/BE prompt block as a direct instruction to the implementer or to another LLM.


<!-- end of md -->

