# tests/test_models.py
# Test database models

import pytest
from datetime import datetime
from uuid import UUID
from app.models.user import User
from app.models.trip import Trip, Day, Activity, Note, BudgetItem
from sqlmodel import Session


def test_create_user(session: Session):
    """Test creating a user."""
    user = User(
        email="test@example.com",
        hashed_password="hashedpassword123",
        name="Test User",
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    
    assert isinstance(user.id, UUID)
    assert user.email == "test@example.com"
    assert user.name == "Test User"
    assert isinstance(user.created_at, datetime)


def test_create_trip(session: Session):
    """Test creating a trip with a user."""
    # Create user first
    user = User(
        email="test@example.com",
        hashed_password="hashedpassword123",
        name="Test User",
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    
    # Create trip
    trip = Trip(
        user_id=user.id,
        title="Paris Adventure",
        destination="Paris, France",
        start_date="2024-06-01",
        end_date="2024-06-07",
        budget=2000.0,
        budget_tier="moderate",
        travel_style="cultural",
        interests=["museums", "food", "history"],
        is_generated=True,
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    assert isinstance(trip.id, UUID)
    assert trip.user_id == user.id
    assert trip.title == "Paris Adventure"
    assert trip.destination == "Paris, France"
    assert trip.budget == 2000.0
    assert trip.budget_tier == "moderate"
    assert trip.interests == ["museums", "food", "history"]
    assert trip.is_generated is True


def test_create_day_with_activities(session: Session):
    """Test creating a day with activities."""
    # Create user and trip
    user = User(email="test@example.com", hashed_password="hash", name="Test")
    session.add(user)
    session.commit()
    
    trip = Trip(
        user_id=user.id,
        title="Paris Adventure",
        destination="Paris",
        start_date="2024-06-01",
        end_date="2024-06-07",
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Create day
    day = Day(
        trip_id=trip.id,
        day_number=1,
        date="2024-06-01",
        title="Arrival Day",
    )
    session.add(day)
    session.commit()
    session.refresh(day)
    
    # Create activities
    activity1 = Activity(
        day_id=day.id,
        time="09:00 AM",
        title="Arrive at Charles de Gaulle",
        description="Land at CDG airport",
        location="Paris CDG Airport",
        estimated_cost=0.0,
    )
    activity2 = Activity(
        day_id=day.id,
        time="11:00 AM",
        title="Check-in at Hotel",
        description="Check into hotel in Marais district",
        location="Le Marais",
        estimated_cost=150.0,
    )
    session.add(activity1)
    session.add(activity2)
    session.commit()
    
    assert isinstance(day.id, UUID)
    assert day.trip_id == trip.id
    assert day.day_number == 1
    assert day.title == "Arrival Day"


def test_create_budget_items(session: Session):
    """Test creating budget items."""
    # Create user and trip
    user = User(email="test@example.com", hashed_password="hash", name="Test")
    session.add(user)
    session.commit()
    
    trip = Trip(
        user_id=user.id,
        title="Paris Adventure",
        destination="Paris",
        start_date="2024-06-01",
        end_date="2024-06-07",
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Create budget items
    budget1 = BudgetItem(
        trip_id=trip.id,
        category="accommodation",
        amount=800.0,
        note="Hotel booking",
    )
    budget2 = BudgetItem(
        trip_id=trip.id,
        category="food",
        amount=400.0,
        note="Restaurants and cafes",
    )
    session.add(budget1)
    session.add(budget2)
    session.commit()
    
    assert isinstance(budget1.id, UUID)
    assert budget1.category == "accommodation"
    assert budget1.amount == 800.0


def test_create_notes(session: Session):
    """Test creating notes."""
    # Create user and trip
    user = User(email="test@example.com", hashed_password="hash", name="Test")
    session.add(user)
    session.commit()
    
    trip = Trip(
        user_id=user.id,
        title="Paris Adventure",
        destination="Paris",
        start_date="2024-06-01",
        end_date="2024-06-07",
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Create note
    note = Note(
        trip_id=trip.id,
        content="Remember to book Eiffel Tower tickets in advance!",
    )
    session.add(note)
    session.commit()
    session.refresh(note)
    
    assert isinstance(note.id, UUID)
    assert note.trip_id == trip.id
    assert "Eiffel Tower" in note.content


def test_sync_fields(session: Session):
    """Test sync fields are properly set."""
    user = User(email="test@example.com", hashed_password="hash", name="Test")
    session.add(user)
    session.commit()
    
    trip = Trip(
        user_id=user.id,
        title="Paris Adventure",
        destination="Paris",
        start_date="2024-06-01",
        end_date="2024-06-07",
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Check sync fields
    assert trip.server_id is None
    assert trip.is_synced is False
    assert isinstance(trip.local_updated_at, datetime)
