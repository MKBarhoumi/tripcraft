# tests/test_auth.py
# Test authentication endpoints

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.models.user import User
from app.core.security import get_password_hash


def test_register_new_user(client: TestClient):
    """Test registering a new user."""
    response = client.post(
        "/api/auth/register",
        json={
            "email": "newuser@example.com",
            "password": "SecurePass123!",
            "name": "New User"
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    
    # Check response structure
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert "user" in data
    
    # Check user data
    user_data = data["user"]
    assert user_data["email"] == "newuser@example.com"
    assert user_data["name"] == "New User"
    assert "id" in user_data
    assert "created_at" in user_data
    
    # Verify password is not in response
    assert "password" not in user_data
    assert "hashed_password" not in user_data


def test_register_duplicate_email(client: TestClient, session: Session):
    """Test registering with an already existing email."""
    # Create existing user
    existing_user = User(
        email="existing@example.com",
        hashed_password=get_password_hash("password123"),
        name="Existing User"
    )
    session.add(existing_user)
    session.commit()
    
    # Try to register with same email
    response = client.post(
        "/api/auth/register",
        json={
            "email": "existing@example.com",
            "password": "NewPassword456!",
            "name": "Another User"
        }
    )
    
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"].lower()


def test_register_without_name(client: TestClient):
    """Test registering without optional name field."""
    response = client.post(
        "/api/auth/register",
        json={
            "email": "noname@example.com",
            "password": "SecurePass123!"
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["user"]["email"] == "noname@example.com"
    assert data["user"]["name"] is None


def test_login_success(client: TestClient, session: Session):
    """Test successful login."""
    # Create user
    user = User(
        email="testuser@example.com",
        hashed_password=get_password_hash("password123"),
        name="Test User"
    )
    session.add(user)
    session.commit()
    
    # Login
    response = client.post(
        "/api/auth/login",
        json={
            "email": "testuser@example.com",
            "password": "password123"
        }
    )
    
    assert response.status_code == 200
    data = response.json()
    
    # Check response structure
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert "user" in data
    
    # Check user data
    user_data = data["user"]
    assert user_data["email"] == "testuser@example.com"
    assert user_data["name"] == "Test User"


def test_login_wrong_password(client: TestClient, session: Session):
    """Test login with incorrect password."""
    # Create user
    user = User(
        email="testuser@example.com",
        hashed_password=get_password_hash("correctpassword"),
        name="Test User"
    )
    session.add(user)
    session.commit()
    
    # Try to login with wrong password
    response = client.post(
        "/api/auth/login",
        json={
            "email": "testuser@example.com",
            "password": "wrongpassword"
        }
    )
    
    assert response.status_code == 401
    assert "incorrect" in response.json()["detail"].lower()


def test_login_nonexistent_user(client: TestClient):
    """Test login with email that doesn't exist."""
    response = client.post(
        "/api/auth/login",
        json={
            "email": "nonexistent@example.com",
            "password": "somepassword"
        }
    )
    
    assert response.status_code == 401
    assert "incorrect" in response.json()["detail"].lower()


def test_get_current_user(client: TestClient, session: Session):
    """Test getting current user information."""
    # Create and login user
    user = User(
        email="currentuser@example.com",
        hashed_password=get_password_hash("password123"),
        name="Current User"
    )
    session.add(user)
    session.commit()
    
    # Login to get token
    login_response = client.post(
        "/api/auth/login",
        json={
            "email": "currentuser@example.com",
            "password": "password123"
        }
    )
    token = login_response.json()["access_token"]
    
    # Get current user info
    response = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "currentuser@example.com"
    assert data["name"] == "Current User"
    assert "id" in data
    assert "created_at" in data


def test_get_current_user_no_token(client: TestClient):
    """Test getting current user without authentication token."""
    response = client.get("/api/auth/me")
    
    assert response.status_code == 403  # No credentials provided


def test_get_current_user_invalid_token(client: TestClient):
    """Test getting current user with invalid token."""
    response = client.get(
        "/api/auth/me",
        headers={"Authorization": "Bearer invalid_token_here"}
    )
    
    assert response.status_code == 401


def test_delete_account(client: TestClient, session: Session):
    """Test deleting user account."""
    # Create and login user
    user = User(
        email="deleteuser@example.com",
        hashed_password=get_password_hash("password123"),
        name="Delete Me"
    )
    session.add(user)
    session.commit()
    user_id = user.id
    
    # Login to get token
    login_response = client.post(
        "/api/auth/login",
        json={
            "email": "deleteuser@example.com",
            "password": "password123"
        }
    )
    token = login_response.json()["access_token"]
    
    # Delete account
    response = client.delete(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 204
    
    # Verify user is deleted
    from sqlmodel import select
    statement = select(User).where(User.id == user_id)
    deleted_user = session.exec(statement).first()
    assert deleted_user is None


def test_delete_account_no_token(client: TestClient):
    """Test deleting account without authentication."""
    response = client.delete("/api/auth/me")
    
    assert response.status_code == 403


def test_token_contains_user_id(client: TestClient, session: Session):
    """Test that JWT token contains user ID in subject claim."""
    # Create and register user
    response = client.post(
        "/api/auth/register",
        json={
            "email": "tokentest@example.com",
            "password": "password123",
            "name": "Token Test"
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    user_id = data["user"]["id"]
    token = data["access_token"]
    
    # Decode token to verify it contains user ID
    from app.core.security import verify_token
    payload = verify_token(token)
    
    assert payload is not None
    assert "sub" in payload
    assert payload["sub"] == user_id


def test_password_is_hashed(client: TestClient, session: Session):
    """Test that passwords are properly hashed in database."""
    # Register user
    password = "MySecurePassword123!"
    response = client.post(
        "/api/auth/register",
        json={
            "email": "hashtest@example.com",
            "password": password,
            "name": "Hash Test"
        }
    )
    
    assert response.status_code == 201
    user_email = response.json()["user"]["email"]
    
    # Query user from database
    from sqlmodel import select
    statement = select(User).where(User.email == user_email)
    user = session.exec(statement).first()
    
    # Verify password is hashed (not stored in plain text)
    assert user.hashed_password != password
    assert len(user.hashed_password) > 50  # Bcrypt hashes are ~60 chars
    
    # Verify we can still verify the password
    from app.core.security import verify_password
    assert verify_password(password, user.hashed_password)
