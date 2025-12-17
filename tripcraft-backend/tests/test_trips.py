# tests/test_trips.py
# Test trip CRUD endpoints

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.models.user import User
from app.models.trip import Trip, Day, Activity, BudgetItem, Note
from app.core.security import get_password_hash


@pytest.fixture(name="test_user")
def test_user_fixture(session: Session) -> User:
    """Create a test user."""
    user = User(
        email="tripuser@example.com",
        hashed_password=get_password_hash("password123"),
        name="Trip User"
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


@pytest.fixture(name="auth_token")
def auth_token_fixture(client: TestClient) -> str:
    """Get authentication token for test user."""
    # Register and login
    client.post(
        "/api/auth/register",
        json={
            "email": "authuser@example.com",
            "password": "password123",
            "name": "Auth User"
        }
    )
    
    response = client.post(
        "/api/auth/login",
        json={
            "email": "authuser@example.com",
            "password": "password123"
        }
    )
    return response.json()["access_token"]


def test_create_trip(client: TestClient, auth_token: str):
    """Test creating a new trip."""
    response = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Paris Adventure",
            "destination": "Paris, France",
            "start_date": "2024-06-01",
            "end_date": "2024-06-07",
            "budget": 2000.0,
            "budget_tier": "moderate",
            "travel_style": "cultural",
            "interests": ["museums", "food", "history"],
            "special_requirements": "Vegetarian meals"
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    
    assert data["title"] == "Paris Adventure"
    assert data["destination"] == "Paris, France"
    assert data["budget"] == 2000.0
    assert data["budget_tier"] == "moderate"
    assert data["travel_style"] == "cultural"
    assert data["interests"] == ["museums", "food", "history"]
    assert data["is_generated"] is False
    assert "id" in data
    assert "created_at" in data


def test_create_trip_minimal(client: TestClient, auth_token: str):
    """Test creating a trip with minimal required fields."""
    response = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Weekend Getaway",
            "destination": "London",
            "start_date": "2024-07-01",
            "end_date": "2024-07-03"
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    
    assert data["title"] == "Weekend Getaway"
    assert data["destination"] == "London"
    assert data["budget"] is None
    assert data["budget_tier"] is None


def test_create_trip_no_auth(client: TestClient):
    """Test creating a trip without authentication."""
    response = client.post(
        "/api/trips",
        json={
            "title": "Test Trip",
            "destination": "Test Destination",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    
    assert response.status_code == 403


def test_list_trips(client: TestClient, auth_token: str):
    """Test listing all trips for a user."""
    # Create a few trips
    for i in range(3):
        client.post(
            "/api/trips",
            headers={"Authorization": f"Bearer {auth_token}"},
            json={
                "title": f"Trip {i+1}",
                "destination": f"Destination {i+1}",
                "start_date": "2024-01-01",
                "end_date": "2024-01-07"
            }
        )
    
    # List trips
    response = client.get(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert len(data) == 3
    assert all("id" in trip for trip in data)
    assert all("title" in trip for trip in data)


def test_list_trips_with_search(client: TestClient, auth_token: str):
    """Test listing trips with search filter."""
    # Create trips
    client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Paris Adventure",
            "destination": "Paris, France",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Tokyo Journey",
            "destination": "Tokyo, Japan",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    
    # Search for Paris
    response = client.get(
        "/api/trips?search=Paris",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert len(data) == 1
    assert data[0]["title"] == "Paris Adventure"


def test_list_trips_pagination(client: TestClient, auth_token: str):
    """Test trip listing with pagination."""
    # Create 5 trips
    for i in range(5):
        client.post(
            "/api/trips",
            headers={"Authorization": f"Bearer {auth_token}"},
            json={
                "title": f"Trip {i+1}",
                "destination": f"Destination {i+1}",
                "start_date": "2024-01-01",
                "end_date": "2024-01-07"
            }
        )
    
    # Get first 2
    response = client.get(
        "/api/trips?skip=0&limit=2",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    
    # Get next 2
    response = client.get(
        "/api/trips?skip=2&limit=2",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


def test_get_trip(client: TestClient, auth_token: str):
    """Test getting a single trip by ID."""
    # Create trip
    create_response = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Barcelona Trip",
            "destination": "Barcelona, Spain",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    trip_id = create_response.json()["id"]
    
    # Get trip
    response = client.get(
        f"/api/trips/{trip_id}",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert data["id"] == trip_id
    assert data["title"] == "Barcelona Trip"
    assert "days" in data
    assert "budget_items" in data
    assert "notes" in data


def test_get_trip_not_found(client: TestClient, auth_token: str):
    """Test getting a non-existent trip."""
    response = client.get(
        "/api/trips/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 404


def test_get_trip_wrong_user(client: TestClient, session: Session):
    """Test getting a trip that belongs to another user."""
    from fastapi.testclient import TestClient as TC
    from app.main import app
    
    # Create first user and trip
    user1 = User(
        email="user1@example.com",
        hashed_password=get_password_hash("password123"),
        name="User 1"
    )
    session.add(user1)
    session.commit()
    session.refresh(user1)
    
    trip = Trip(
        user_id=user1.id,
        title="User 1 Trip",
        destination="Somewhere",
        start_date="2024-01-01",
        end_date="2024-01-07"
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Create second user
    test_client = TC(app)
    register_response = test_client.post(
        "/api/auth/register",
        json={
            "email": "user2@example.com",
            "password": "password123",
            "name": "User 2"
        }
    )
    token = register_response.json()["access_token"]
    
    # Try to get user1's trip as user2
    response = test_client.get(
        f"/api/trips/{trip.id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 404


def test_update_trip(client: TestClient, auth_token: str):
    """Test updating a trip."""
    # Create trip
    create_response = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Original Title",
            "destination": "Original Destination",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07",
            "budget": 1000.0
        }
    )
    trip_id = create_response.json()["id"]
    
    # Update trip
    response = client.put(
        f"/api/trips/{trip_id}",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Updated Title",
            "budget": 1500.0
        }
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert data["title"] == "Updated Title"
    assert data["budget"] == 1500.0
    assert data["destination"] == "Original Destination"  # Unchanged


def test_update_trip_not_found(client: TestClient, auth_token: str):
    """Test updating a non-existent trip."""
    response = client.put(
        "/api/trips/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"title": "Updated"}
    )
    
    assert response.status_code == 404


def test_delete_trip(client: TestClient, auth_token: str):
    """Test deleting a trip."""
    # Create trip
    create_response = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Trip to Delete",
            "destination": "Somewhere",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    trip_id = create_response.json()["id"]
    
    # Delete trip
    response = client.delete(
        f"/api/trips/{trip_id}",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 204
    
    # Verify trip is deleted
    get_response = client.get(
        f"/api/trips/{trip_id}",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert get_response.status_code == 404


def test_delete_trip_not_found(client: TestClient, auth_token: str):
    """Test deleting a non-existent trip."""
    response = client.delete(
        "/api/trips/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 404


def test_trip_with_nested_data(client: TestClient, auth_token: str, session: Session):
    """Test that trip response includes nested days, activities, budget items, and notes."""
    # Create trip
    create_response = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "title": "Complete Trip",
            "destination": "Rome, Italy",
            "start_date": "2024-01-01",
            "end_date": "2024-01-03"
        }
    )
    trip_id = create_response.json()["id"]
    
    # Manually add nested data to database
    from uuid import UUID
    from app.models.trip import Trip, Day, Activity, BudgetItem, Note
    
    trip_uuid = UUID(trip_id)
    
    # Add day
    day = Day(
        trip_id=trip_uuid,
        day_number=1,
        date="2024-01-01",
        title="Day 1"
    )
    session.add(day)
    session.commit()
    session.refresh(day)
    
    # Add activity
    activity = Activity(
        day_id=day.id,
        time="09:00 AM",
        title="Visit Colosseum",
        description="Explore ancient Rome",
        location="Colosseum",
        estimated_cost=15.0
    )
    session.add(activity)
    
    # Add budget item
    budget_item = BudgetItem(
        trip_id=trip_uuid,
        category="accommodation",
        amount=500.0,
        note="Hotel booking"
    )
    session.add(budget_item)
    
    # Add note
    note = Note(
        trip_id=trip_uuid,
        content="Remember to bring comfortable shoes!"
    )
    session.add(note)
    
    session.commit()
    
    # Get trip and verify nested data
    response = client.get(
        f"/api/trips/{trip_id}",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert len(data["days"]) == 1
    assert data["days"][0]["day_number"] == 1
    assert len(data["days"][0]["activities"]) == 1
    assert data["days"][0]["activities"][0]["title"] == "Visit Colosseum"
    
    assert len(data["budget_items"]) == 1
    assert data["budget_items"][0]["category"] == "accommodation"
    
    assert len(data["notes"]) == 1
    assert "comfortable shoes" in data["notes"][0]["content"]


def test_list_trips_isolation(client: TestClient, session: Session):
    """Test that users can only see their own trips."""
    # Create two users
    user1_response = client.post(
        "/api/auth/register",
        json={
            "email": "isolation1@example.com",
            "password": "password123",
            "name": "User 1"
        }
    )
    token1 = user1_response.json()["access_token"]
    
    user2_response = client.post(
        "/api/auth/register",
        json={
            "email": "isolation2@example.com",
            "password": "password123",
            "name": "User 2"
        }
    )
    token2 = user2_response.json()["access_token"]
    
    # User 1 creates trips
    client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {token1}"},
        json={
            "title": "User 1 Trip 1",
            "destination": "Dest 1",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {token1}"},
        json={
            "title": "User 1 Trip 2",
            "destination": "Dest 2",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    
    # User 2 creates trip
    client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {token2}"},
        json={
            "title": "User 2 Trip",
            "destination": "Dest 3",
            "start_date": "2024-01-01",
            "end_date": "2024-01-07"
        }
    )
    
    # User 1 should only see their 2 trips
    response1 = client.get(
        "/api/trips",
        headers={"Authorization": f"Bearer {token1}"}
    )
    assert len(response1.json()) == 2
    
    # User 2 should only see their 1 trip
    response2 = client.get(
        "/api/trips",
        headers={"Authorization": f"Bearer {token2}"}
    )
    assert len(response2.json()) == 1
