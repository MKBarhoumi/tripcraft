# TripCraft API - Authentication Guide

## Overview

The TripCraft API uses JWT (JSON Web Token) authentication. All protected endpoints require a valid Bearer token in the Authorization header.

## Endpoints

### 1. Register New User

**Endpoint:** `POST /api/auth/register`

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "John Doe"
}
```

**Response (201 Created):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2024-01-01T12:00:00"
  }
}
```

**Errors:**
- `400 Bad Request`: Email already registered

---

### 2. Login

**Endpoint:** `POST /api/auth/login`

**Request:**
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
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2024-01-01T12:00:00"
  }
}
```

**Errors:**
- `401 Unauthorized`: Incorrect email or password

---

### 3. Get Current User

**Endpoint:** `GET /api/auth/me`

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2024-01-01T12:00:00"
}
```

**Errors:**
- `401 Unauthorized`: Invalid or expired token
- `403 Forbidden`: No token provided

---

### 4. Delete Account

**Endpoint:** `DELETE /api/auth/me`

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:** `204 No Content`

**Errors:**
- `401 Unauthorized`: Invalid or expired token
- `403 Forbidden`: No token provided

**Note:** This will permanently delete the user account and all associated data (trips, days, activities, notes, budget items) due to CASCADE delete.

---

## Using Authentication in Requests

### Python (requests)

```python
import requests

# Login
response = requests.post(
    "http://localhost:8000/api/auth/login",
    json={"email": "user@example.com", "password": "password123"}
)
token = response.json()["access_token"]

# Use token for protected endpoints
headers = {"Authorization": f"Bearer {token}"}
response = requests.get(
    "http://localhost:8000/api/auth/me",
    headers=headers
)
user = response.json()
```

### JavaScript (fetch)

```javascript
// Login
const loginResponse = await fetch('http://localhost:8000/api/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'password123'
  })
});
const { access_token } = await loginResponse.json();

// Use token for protected endpoints
const userResponse = await fetch('http://localhost:8000/api/auth/me', {
  headers: { 'Authorization': `Bearer ${access_token}` }
});
const user = await userResponse.json();
```

### Flutter (Dio)

```dart
import 'package:dio/dio.dart';

final dio = Dio();

// Login
final loginResponse = await dio.post(
  'http://localhost:8000/api/auth/login',
  data: {
    'email': 'user@example.com',
    'password': 'password123',
  },
);
final token = loginResponse.data['access_token'];

// Use token for protected endpoints
dio.options.headers['Authorization'] = 'Bearer $token';
final userResponse = await dio.get('http://localhost:8000/api/auth/me');
final user = userResponse.data;
```

### cURL

```bash
# Login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Get current user (replace TOKEN with actual token)
curl -X GET http://localhost:8000/api/auth/me \
  -H "Authorization: Bearer TOKEN"
```

---

## Token Details

- **Algorithm:** HS256
- **Expiration:** 30 minutes (configurable via `ACCESS_TOKEN_EXPIRE_MINUTES`)
- **Subject Claim:** Contains user UUID
- **Format:** JWT (3 parts: header.payload.signature)

## Security Notes

1. **HTTPS Required:** Always use HTTPS in production
2. **Token Storage:** Store tokens securely (not in localStorage for web apps)
3. **Token Refresh:** Tokens expire after 30 minutes - implement refresh logic
4. **Password Requirements:** Enforce strong passwords in your client app
5. **Rate Limiting:** Consider implementing rate limiting for auth endpoints

## Testing with Swagger UI

1. Start the server: `uvicorn app.main:app --reload`
2. Open http://localhost:8000/docs
3. Click "Authorize" button (lock icon)
4. Login via `/api/auth/login` endpoint
5. Copy the `access_token` from response
6. Paste in authorization modal with format: `Bearer <token>`
7. Now all protected endpoints will include the token automatically
