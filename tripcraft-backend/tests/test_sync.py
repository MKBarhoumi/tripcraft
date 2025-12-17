# tests/test_sync.py
# Tests for sync endpoint

import pytest
from fastapi.testclient import TestClient as TC
from sqlmodel import Session, select
from datetime import datetime, timedelta
import uuid

from app.main import app
from app.models.user import User
from app.models.trip import Trip, Day, Activity, BudgetItem, Note
from app.core.security import create_access_token


@pytest.fixture
def test_user(session_fixture: Session) -> User:
    """Create a test user."""
    user = User(
        email="sync@example.com",
        hashed_password="hashed_password",
        name="Test Sync User"
    )
    session_fixture.add(user)
    session_fixture.commit()
    session_fixture.refresh(user)
    return user


@pytest.fixture
def auth_headers(test_user: User) -> dict:
    """Create authentication headers."""
    token = create_access_token({"sub": str(test_user.id)})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def server_trip(session_fixture: Session, test_user: User) -> Trip:
    """Create a trip on the server."""
    now = datetime.utcnow()
    trip = Trip(
        user_id=test_user.id,
        title="Server Trip",
        destination="Paris, France",
        start_date="2024-06-15",
        end_date="2024-06-17",
        budget=2000.0,
        is_generated=True,
        local_updated_at=now,
        is_synced=True
    )
    session_fixture.add(trip)
    session_fixture.flush()
    
    day = Day(
        trip_id=trip.id,
        day_number=1,
        date="2024-06-15",
        title="Day 1",
        local_updated_at=now,
        is_synced=True
    )
    session_fixture.add(day)
    session_fixture.flush()
    
    activity = Activity(
        day_id=day.id,
        time="09:00 AM",
        title="Breakfast",
        description="Morning meal",
        location="Hotel",
        estimated_cost=15.0,
        local_updated_at=now,
        is_synced=True
    )
    session_fixture.add(activity)
    
    session_fixture.commit()
    session_fixture.refresh(trip)
    return trip


class TestSync:
    """Test suite for sync endpoint."""
    
    def test_sync_empty_request(
        self,
        client_fixture,
        auth_headers: dict
    ):
        """Test sync with no data (just checking for server updates)."""
        response = client_fixture.post(
            "/api/sync",
            json={
                "last_sync_at": None,
                "conflict_resolution": "newer_wins",
                "trips": [],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "sync_timestamp" in data
        assert data["trips_uploaded"] == 0
        assert data["trips_downloaded"] == 0
        assert "server_data" in data
    
    def test_sync_upload_new_trip(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        test_user: User
    ):
        """Test uploading a new trip from client."""
        trip_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "conflict_resolution": "newer_wins",
                "trips": [
                    {
                        "id": trip_id,
                        "title": "Client Trip",
                        "destination": "Tokyo, Japan",
                        "start_date": "2024-07-01",
                        "end_date": "2024-07-05",
                        "budget": 3000.0,
                        "preferences": {"budget_tier": "moderate"},
                        "is_generated": True,
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["trips_uploaded"] == 1
        
        # Verify in database
        trip = session_fixture.get(Trip, trip_id)
        assert trip is not None
        assert trip.title == "Client Trip"
        assert trip.destination == "Tokyo, Japan"
        assert trip.user_id == test_user.id
        assert trip.is_synced is True
    
    def test_sync_upload_trip_with_nested_data(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict
    ):
        """Test uploading trip with days and activities."""
        trip_id = str(uuid.uuid4())
        day_id = str(uuid.uuid4())
        activity_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "trips": [
                    {
                        "id": trip_id,
                        "title": "Full Trip",
                        "destination": "Rome, Italy",
                        "start_date": "2024-08-01",
                        "end_date": "2024-08-03",
                        "budget": 1500.0,
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "days": [
                    {
                        "id": day_id,
                        "trip_id": trip_id,
                        "day_number": 1,
                        "date": "2024-08-01",
                        "title": "Arrival Day",
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "activities": [
                    {
                        "id": activity_id,
                        "day_id": day_id,
                        "time": "10:00 AM",
                        "title": "Colosseum Visit",
                        "description": "Tour ancient amphitheater",
                        "location": "Colosseum",
                        "estimated_cost": 25.0,
                        "is_completed": False,
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["trips_uploaded"] == 1
        assert data["days_uploaded"] == 1
        assert data["activities_uploaded"] == 1
        
        # Verify database
        trip = session_fixture.get(Trip, trip_id)
        assert trip is not None
        
        day = session_fixture.get(Day, day_id)
        assert day is not None
        assert day.trip_id == trip.id
        
        activity = session_fixture.get(Activity, activity_id)
        assert activity is not None
        assert activity.day_id == day.id
    
    def test_sync_update_existing_trip(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        server_trip: Trip
    ):
        """Test updating an existing trip."""
        future = (datetime.utcnow() + timedelta(hours=1)).isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "conflict_resolution": "newer_wins",
                "trips": [
                    {
                        "id": str(server_trip.id),
                        "title": "Updated Server Trip",
                        "destination": "Paris, France",
                        "start_date": "2024-06-15",
                        "end_date": "2024-06-17",
                        "budget": 2500.0,
                        "local_updated_at": future,
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["trips_uploaded"] == 1
        
        # Verify update
        session_fixture.refresh(server_trip)
        assert server_trip.title == "Updated Server Trip"
        assert server_trip.budget == 2500.0
    
    def test_sync_conflict_resolution_newer_wins(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        server_trip: Trip
    ):
        """Test conflict resolution with newer_wins strategy."""
        # Client has older timestamp - should NOT update
        past = (datetime.utcnow() - timedelta(hours=1)).isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "conflict_resolution": "newer_wins",
                "trips": [
                    {
                        "id": str(server_trip.id),
                        "title": "Older Client Update",
                        "local_updated_at": past,
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should have conflict
        assert data["conflicts_resolved"] == 1
        assert len(data["conflicts"]) == 1
        assert data["conflicts"][0]["resolution"] == "server_wins"
        
        # Trip should NOT be updated
        session_fixture.refresh(server_trip)
        assert server_trip.title == "Server Trip"  # Original title
    
    def test_sync_conflict_resolution_client_wins(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        server_trip: Trip
    ):
        """Test conflict resolution with client_wins strategy."""
        past = (datetime.utcnow() - timedelta(hours=1)).isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "conflict_resolution": "client_wins",
                "trips": [
                    {
                        "id": str(server_trip.id),
                        "title": "Client Always Wins",
                        "local_updated_at": past,
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["trips_uploaded"] == 1
        
        # Trip should be updated even with older timestamp
        session_fixture.refresh(server_trip)
        assert server_trip.title == "Client Always Wins"
    
    def test_sync_conflict_resolution_server_wins(
        self,
        client_fixture,
        server_trip: Trip,
        auth_headers: dict
    ):
        """Test conflict resolution with server_wins strategy."""
        future = (datetime.utcnow() + timedelta(hours=1)).isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "conflict_resolution": "server_wins",
                "trips": [
                    {
                        "id": str(server_trip.id),
                        "title": "Server Should Win",
                        "local_updated_at": future,
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should NOT update (conflicts without uploading)
        assert data["trips_uploaded"] == 0
    
    def test_sync_delete_trip(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        server_trip: Trip
    ):
        """Test deleting a trip via sync."""
        trip_id = str(server_trip.id)
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "trips": [
                    {
                        "id": trip_id,
                        "local_updated_at": datetime.utcnow().isoformat(),
                        "is_deleted": True
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["trips_uploaded"] == 1
        
        # Verify deletion
        trip = session_fixture.get(Trip, trip_id)
        assert trip is None
    
    def test_sync_download_server_changes(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        test_user: User
    ):
        """Test downloading changes from server."""
        # Create a trip on server with recent timestamp
        recent = datetime.utcnow()
        trip = Trip(
            user_id=test_user.id,
            title="New Server Trip",
            destination="Berlin, Germany",
            start_date="2024-09-01",
            end_date="2024-09-05",
            budget=1800.0,
            local_updated_at=recent,
            is_synced=True
        )
        session_fixture.add(trip)
        session_fixture.commit()
        
        # Sync with last_sync_at before this trip was created
        past = (recent - timedelta(hours=1)).isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "last_sync_at": past,
                "trips": [],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should download the new trip
        assert data["trips_downloaded"] == 1
        assert len(data["server_data"]["trips"]) == 1
        assert data["server_data"]["trips"][0]["title"] == "New Server Trip"
    
    def test_sync_no_auth(self, client_fixture):
        """Test sync without authentication."""
        response = client_fixture.post(
            "/api/sync",
            json={
                "trips": [],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            }
        )
        
        assert response.status_code == 403
    
    def test_sync_budget_items(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        server_trip: Trip
    ):
        """Test syncing budget items."""
        item_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "trips": [],
                "days": [],
                "activities": [],
                "budget_items": [
                    {
                        "id": item_id,
                        "trip_id": str(server_trip.id),
                        "category": "Accommodation",
                        "amount": 500.0,
                        "note": "Hotel booking",
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["budget_items_uploaded"] == 1
        
        # Verify in database
        item = session_fixture.get(BudgetItem, item_id)
        assert item is not None
        assert item.category == "Accommodation"
        assert item.amount == 500.0
    
    def test_sync_notes(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        server_trip: Trip
    ):
        """Test syncing notes."""
        note_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "trips": [],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": [
                    {
                        "id": note_id,
                        "trip_id": str(server_trip.id),
                        "content": "Remember to pack sunscreen",
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ]
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["notes_uploaded"] == 1
        
        # Verify in database
        note = session_fixture.get(Note, note_id)
        assert note is not None
        assert note.content == "Remember to pack sunscreen"
    
    def test_sync_unauthorized_trip(
        self,
        client_fixture,
        session_fixture: Session,
        server_trip: Trip
    ):
        """Test syncing with different user cannot access trip."""
        # Create another user
        other_user = User(
            email="other@example.com",
            hashed_password="hashed",
            name="Other User"
        )
        session_fixture.add(other_user)
        session_fixture.commit()
        
        token = create_access_token({"sub": str(other_user.id)})
        headers = {"Authorization": f"Bearer {token}"}
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "trips": [
                    {
                        "id": str(server_trip.id),
                        "title": "Hacked Title",
                        "local_updated_at": datetime.utcnow().isoformat(),
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should not update (silently ignored)
        assert data["trips_uploaded"] == 0
        
        # Trip should be unchanged
        session_fixture.refresh(server_trip)
        assert server_trip.title == "Server Trip"
    
    def test_sync_full_bidirectional(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        test_user: User
    ):
        """Test full bidirectional sync (upload and download)."""
        # Create server trip
        server_trip = Trip(
            user_id=test_user.id,
            title="Server Trip",
            destination="Madrid, Spain",
            start_date="2024-10-01",
            end_date="2024-10-03",
            local_updated_at=datetime.utcnow()
        )
        session_fixture.add(server_trip)
        session_fixture.commit()
        
        # Client uploads new trip
        client_trip_id = str(uuid.uuid4())
        past = (datetime.utcnow() - timedelta(minutes=5)).isoformat()
        now = datetime.utcnow().isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "last_sync_at": past,
                "trips": [
                    {
                        "id": client_trip_id,
                        "title": "Client Trip",
                        "destination": "Barcelona, Spain",
                        "start_date": "2024-11-01",
                        "end_date": "2024-11-03",
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should upload client trip
        assert data["trips_uploaded"] == 1
        
        # Should download server trip
        assert data["trips_downloaded"] == 1
        assert len(data["server_data"]["trips"]) == 1
        assert data["server_data"]["trips"][0]["title"] == "Server Trip"
    
    def test_sync_partial_update(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        server_trip: Trip
    ):
        """Test partial updates (only some fields provided)."""
        future = (datetime.utcnow() + timedelta(hours=1)).isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "conflict_resolution": "newer_wins",
                "trips": [
                    {
                        "id": str(server_trip.id),
                        "title": "Partially Updated",
                        # Only title provided, other fields should remain
                        "local_updated_at": future,
                        "is_deleted": False
                    }
                ],
                "days": [],
                "activities": [],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        
        # Verify partial update
        session_fixture.refresh(server_trip)
        assert server_trip.title == "Partially Updated"
        assert server_trip.destination == "Paris, France"  # Unchanged
        assert server_trip.budget == 2000.0  # Unchanged
    
    def test_sync_complex_scenario(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        test_user: User
    ):
        """Test complex sync with multiple operations."""
        # Create existing data
        existing_trip = Trip(
            user_id=test_user.id,
            title="Existing Trip",
            destination="London, UK",
            start_date="2024-12-01",
            end_date="2024-12-03",
            local_updated_at=datetime.utcnow()
        )
        session_fixture.add(existing_trip)
        session_fixture.commit()
        
        new_trip_id = str(uuid.uuid4())
        new_day_id = str(uuid.uuid4())
        new_activity_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        future = (datetime.utcnow() + timedelta(hours=1)).isoformat()
        
        response = client_fixture.post(
            "/api/sync",
            json={
                "conflict_resolution": "newer_wins",
                "trips": [
                    # Update existing
                    {
                        "id": str(existing_trip.id),
                        "title": "Updated London Trip",
                        "local_updated_at": future,
                        "is_deleted": False
                    },
                    # Create new
                    {
                        "id": new_trip_id,
                        "title": "New Trip",
                        "destination": "Dublin, Ireland",
                        "start_date": "2025-01-01",
                        "end_date": "2025-01-03",
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "days": [
                    {
                        "id": new_day_id,
                        "trip_id": new_trip_id,
                        "day_number": 1,
                        "date": "2025-01-01",
                        "title": "Day 1",
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "activities": [
                    {
                        "id": new_activity_id,
                        "day_id": new_day_id,
                        "time": "10:00 AM",
                        "title": "Temple Bar Visit",
                        "local_updated_at": now,
                        "is_deleted": False
                    }
                ],
                "budget_items": [],
                "notes": []
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["trips_uploaded"] == 2  # 1 update + 1 create
        assert data["days_uploaded"] == 1
        assert data["activities_uploaded"] == 1
        
        # Verify updates
        session_fixture.refresh(existing_trip)
        assert existing_trip.title == "Updated London Trip"
        
        # Verify new entities
        new_trip = session_fixture.get(Trip, new_trip_id)
        assert new_trip is not None
        assert new_trip.title == "New Trip"
