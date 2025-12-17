# tests/test_chat.py
# Tests for chat refinement endpoint

import pytest
from fastapi.testclient import TestClient as TC
from sqlmodel import Session, select
from unittest.mock import patch, MagicMock
import json
from datetime import datetime, timedelta

from app.main import app
from app.models.user import User
from app.models.trip import Trip, Day, Activity
from app.core.security import create_access_token


@pytest.fixture
def test_user(session_fixture: Session) -> User:
    """Create a test user."""
    user = User(
        email="chat@example.com",
        hashed_password="hashed_password",
        name="Test Chat User"
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
def sample_trip(session_fixture: Session, test_user: User) -> Trip:
    """Create a sample trip with days and activities."""
    trip = Trip(
        user_id=test_user.id,
        title="Paris Adventure",
        destination="Paris, France",
        start_date="2024-06-15",
        end_date="2024-06-17",
        budget=2000.0,
        preferences={
            "budget_tier": "moderate",
            "travel_style": "cultural",
            "interests": ["art", "food", "history"]
        },
        is_generated=True
    )
    session_fixture.add(trip)
    session_fixture.flush()
    
    # Day 1
    day1 = Day(
        trip_id=trip.id,
        day_number=1,
        date="2024-06-15",
        title="Day 1: Arrival"
    )
    session_fixture.add(day1)
    session_fixture.flush()
    
    activity1 = Activity(
        day_id=day1.id,
        time="09:00 AM",
        title="Arrive in Paris",
        description="Land at Charles de Gaulle Airport",
        location="CDG Airport",
        estimated_cost=0.0
    )
    activity2 = Activity(
        day_id=day1.id,
        time="02:00 PM",
        title="Check into Hotel",
        description="Check into accommodation",
        location="Hotel in Marais",
        estimated_cost=150.0
    )
    session_fixture.add(activity1)
    session_fixture.add(activity2)
    
    # Day 2
    day2 = Day(
        trip_id=trip.id,
        day_number=2,
        date="2024-06-16",
        title="Day 2: Sightseeing"
    )
    session_fixture.add(day2)
    session_fixture.flush()
    
    activity3 = Activity(
        day_id=day2.id,
        time="10:00 AM",
        title="Visit Louvre Museum",
        description="Explore world-famous art museum",
        location="Louvre Museum",
        estimated_cost=25.0
    )
    activity4 = Activity(
        day_id=day2.id,
        time="06:00 PM",
        title="Dinner at Local Bistro",
        description="Try traditional French cuisine",
        location="Le Marais",
        estimated_cost=50.0
    )
    session_fixture.add(activity3)
    session_fixture.add(activity4)
    
    # Day 3
    day3 = Day(
        trip_id=trip.id,
        day_number=3,
        date="2024-06-17",
        title="Day 3: Departure"
    )
    session_fixture.add(day3)
    session_fixture.flush()
    
    activity5 = Activity(
        day_id=day3.id,
        time="11:00 AM",
        title="Depart Paris",
        description="Head to airport for departure",
        location="CDG Airport",
        estimated_cost=0.0
    )
    session_fixture.add(activity5)
    
    session_fixture.commit()
    session_fixture.refresh(trip)
    return trip


@pytest.fixture
def mock_refined_response():
    """Mock refined AI response."""
    return {
        "days": [
            {
                "day_number": 1,
                "date": "2024-06-15",
                "title": "Day 1: Arrival and Exploration",
                "activities": [
                    {
                        "time": "09:00 AM",
                        "title": "Arrive in Paris",
                        "description": "Land at Charles de Gaulle Airport",
                        "location": "CDG Airport",
                        "estimated_cost": 0.0
                    },
                    {
                        "time": "02:00 PM",
                        "title": "Check into Hotel",
                        "description": "Check into accommodation in trendy Marais",
                        "location": "Hotel in Marais",
                        "estimated_cost": 150.0
                    },
                    {
                        "time": "05:00 PM",
                        "title": "Visit Eiffel Tower",
                        "description": "Added per user request - see iconic landmark",
                        "location": "Eiffel Tower",
                        "estimated_cost": 30.0,
                        "notes": "Book tickets in advance"
                    }
                ]
            },
            {
                "day_number": 2,
                "date": "2024-06-16",
                "title": "Day 2: Museums and Art",
                "activities": [
                    {
                        "time": "10:00 AM",
                        "title": "Visit Louvre Museum",
                        "description": "Explore world-famous art museum",
                        "location": "Louvre Museum",
                        "estimated_cost": 25.0
                    },
                    {
                        "time": "02:00 PM",
                        "title": "Musée d'Orsay",
                        "description": "Impressionist art collection",
                        "location": "Musée d'Orsay",
                        "estimated_cost": 20.0
                    },
                    {
                        "time": "06:00 PM",
                        "title": "Dinner at Local Bistro",
                        "description": "Try traditional French cuisine",
                        "location": "Le Marais",
                        "estimated_cost": 50.0
                    }
                ]
            },
            {
                "day_number": 3,
                "date": "2024-06-17",
                "title": "Day 3: Departure",
                "activities": [
                    {
                        "time": "09:00 AM",
                        "title": "Morning Croissant at Café",
                        "description": "Leisurely breakfast before departure",
                        "location": "Local Café",
                        "estimated_cost": 15.0
                    },
                    {
                        "time": "11:00 AM",
                        "title": "Depart Paris",
                        "description": "Head to airport for departure",
                        "location": "CDG Airport",
                        "estimated_cost": 0.0
                    }
                ]
            }
        ]
    }


class TestChatRefinement:
    """Test suite for chat refinement endpoint."""
    
    def test_refine_success(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        sample_trip: Trip,
        mock_refined_response: dict
    ):
        """Test successful itinerary refinement."""
        with patch('app.api.chat.AIService') as mock_ai:
            # Mock AI service
            mock_ai_instance = MagicMock()
            mock_ai_instance.refine_itinerary.return_value = mock_refined_response
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/chat",
                json={
                    "trip_id": str(sample_trip.id),
                    "message": "Add a visit to the Eiffel Tower on Day 1"
                },
                headers=auth_headers
            )
            
            assert response.status_code == 200
            data = response.json()
            
            assert "trip" in data
            assert "message" in data
            assert "ai_response" in data
            assert "refined" in data["message"].lower()
            
            trip = data["trip"]
            assert trip["id"] == str(sample_trip.id)
            assert len(trip["days"]) == 3
            
            # Check Day 1 now has 3 activities (added Eiffel Tower)
            day1 = trip["days"][0]
            assert len(day1["activities"]) == 3
            assert any("Eiffel Tower" in act["title"] for act in day1["activities"])
            
            # Verify AI service was called with correct parameters
            mock_ai_instance.refine_itinerary.assert_called_once()
            call_args = mock_ai_instance.refine_itinerary.call_args[1]
            assert call_args["refinement_request"] == "Add a visit to the Eiffel Tower on Day 1"
            assert "current_itinerary" in call_args
            assert "trip_context" in call_args
            
            # Verify database was updated
            db_days = session_fixture.exec(
                select(Day).where(Day.trip_id == sample_trip.id)
            ).all()
            assert len(db_days) == 3
            
            # Check activities were updated
            all_activities = []
            for day in db_days:
                activities = session_fixture.exec(
                    select(Activity).where(Activity.day_id == day.id)
                ).all()
                all_activities.extend(activities)
            
            assert len(all_activities) == 8  # 3 + 3 + 2
    
    def test_refine_trip_not_found(
        self,
        client_fixture,
        auth_headers: dict
    ):
        """Test refinement with non-existent trip."""
        response = client_fixture.post(
            "/api/chat",
            json={
                "trip_id": "00000000-0000-0000-0000-000000000000",
                "message": "Make it better"
            },
            headers=auth_headers
        )
        
        assert response.status_code == 404
        assert "Trip not found" in response.json()["detail"]
    
    def test_refine_no_auth(self, client_fixture, sample_trip: Trip):
        """Test refinement without authentication."""
        response = client_fixture.post(
            "/api/chat",
            json={
                "trip_id": str(sample_trip.id),
                "message": "Make it better"
            }
        )
        
        assert response.status_code == 403
    
    def test_refine_wrong_user(
        self,
        client_fixture,
        session_fixture: Session,
        sample_trip: Trip
    ):
        """Test refinement with different user."""
        # Create another user
        other_user = User(
            email="other@example.com",
            hashed_password="hashed",
            name="Other User"
        )
        session_fixture.add(other_user)
        session_fixture.commit()
        
        # Get token for other user
        token = create_access_token({"sub": str(other_user.id)})
        headers = {"Authorization": f"Bearer {token}"}
        
        response = client_fixture.post(
            "/api/chat",
            json={
                "trip_id": str(sample_trip.id),
                "message": "Make it better"
            },
            headers=headers
        )
        
        assert response.status_code == 403
        assert "Not authorized" in response.json()["detail"]
    
    def test_refine_empty_message(
        self,
        client_fixture,
        auth_headers: dict,
        sample_trip: Trip
    ):
        """Test refinement with empty message."""
        response = client_fixture.post(
            "/api/chat",
            json={
                "trip_id": str(sample_trip.id),
                "message": ""
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422
    
    def test_refine_message_too_long(
        self,
        client_fixture,
        auth_headers: dict,
        sample_trip: Trip
    ):
        """Test refinement with message exceeding max length."""
        long_message = "x" * 2001  # Exceeds 2000 char limit
        
        response = client_fixture.post(
            "/api/chat",
            json={
                "trip_id": str(sample_trip.id),
                "message": long_message
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422
    
    def test_refine_trip_with_no_days(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        test_user: User
    ):
        """Test refinement on trip with no days."""
        # Create trip without days
        empty_trip = Trip(
            user_id=test_user.id,
            title="Empty Trip",
            destination="Nowhere",
            start_date="2024-06-15",
            end_date="2024-06-17",
            is_generated=False
        )
        session_fixture.add(empty_trip)
        session_fixture.commit()
        
        response = client_fixture.post(
            "/api/chat",
            json={
                "trip_id": str(empty_trip.id),
                "message": "Add some activities"
            },
            headers=auth_headers
        )
        
        assert response.status_code == 400
        assert "no days" in response.json()["detail"].lower()
    
    def test_refine_ai_service_error(
        self,
        client_fixture,
        auth_headers: dict,
        sample_trip: Trip
    ):
        """Test refinement when AI service fails."""
        with patch('app.api.chat.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            mock_ai_instance.refine_itinerary.side_effect = ValueError("AI error")
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/chat",
                json={
                    "trip_id": str(sample_trip.id),
                    "message": "Make it better"
                },
                headers=auth_headers
            )
            
            assert response.status_code == 400
            assert "AI error" in response.json()["detail"]
    
    def test_refine_preserves_trip_data(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        sample_trip: Trip,
        mock_refined_response: dict
    ):
        """Test that refinement preserves core trip data."""
        original_title = sample_trip.title
        original_destination = sample_trip.destination
        original_budget = sample_trip.budget
        
        with patch('app.api.chat.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            mock_ai_instance.refine_itinerary.return_value = mock_refined_response
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/chat",
                json={
                    "trip_id": str(sample_trip.id),
                    "message": "Add more museums"
                },
                headers=auth_headers
            )
            
            assert response.status_code == 200
            trip = response.json()["trip"]
            
            # Verify core trip data unchanged
            assert trip["title"] == original_title
            assert trip["destination"] == original_destination
            assert trip["budget"] == original_budget
    
    def test_get_suggestions_success(
        self,
        client_fixture,
        auth_headers: dict,
        sample_trip: Trip
    ):
        """Test getting refinement suggestions."""
        response = client_fixture.get(
            f"/api/chat/suggestions/{sample_trip.id}",
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "suggestions" in data
        assert "trip_id" in data
        assert "destination" in data
        assert len(data["suggestions"]) > 0
        assert len(data["suggestions"]) <= 8
        assert data["trip_id"] == str(sample_trip.id)
        assert data["destination"] == sample_trip.destination
    
    def test_get_suggestions_trip_not_found(
        self,
        client_fixture,
        auth_headers: dict
    ):
        """Test suggestions for non-existent trip."""
        response = client_fixture.get(
            "/api/chat/suggestions/00000000-0000-0000-0000-000000000000",
            headers=auth_headers
        )
        
        assert response.status_code == 404
    
    def test_get_suggestions_no_auth(
        self,
        client_fixture,
        sample_trip: Trip
    ):
        """Test suggestions without authentication."""
        response = client_fixture.get(
            f"/api/chat/suggestions/{sample_trip.id}"
        )
        
        assert response.status_code == 403
    
    def test_get_suggestions_wrong_user(
        self,
        client_fixture,
        session_fixture: Session,
        sample_trip: Trip
    ):
        """Test suggestions with different user."""
        other_user = User(
            email="other2@example.com",
            hashed_password="hashed",
            name="Other User 2"
        )
        session_fixture.add(other_user)
        session_fixture.commit()
        
        token = create_access_token({"sub": str(other_user.id)})
        headers = {"Authorization": f"Bearer {token}"}
        
        response = client_fixture.get(
            f"/api/chat/suggestions/{sample_trip.id}",
            headers=headers
        )
        
        assert response.status_code == 403
    
    def test_get_suggestions_budget_tier_specific(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        test_user: User
    ):
        """Test that suggestions are tailored to budget tier."""
        # Create luxury trip
        luxury_trip = Trip(
            user_id=test_user.id,
            title="Luxury Trip",
            destination="Monaco",
            start_date="2024-06-15",
            end_date="2024-06-20",
            budget=10000.0,
            preferences={"budget_tier": "luxury"},
            is_generated=True
        )
        session_fixture.add(luxury_trip)
        session_fixture.commit()
        
        response = client_fixture.get(
            f"/api/chat/suggestions/{luxury_trip.id}",
            headers=auth_headers
        )
        
        assert response.status_code == 200
        suggestions = response.json()["suggestions"]
        
        # Should include luxury-specific suggestions
        suggestions_text = " ".join(suggestions).lower()
        assert any(word in suggestions_text for word in ["spa", "private", "exclusive", "wellness"])
    
    def test_refine_complex_message(
        self,
        client_fixture,
        auth_headers: dict,
        sample_trip: Trip,
        mock_refined_response: dict
    ):
        """Test refinement with complex multi-part message."""
        with patch('app.api.chat.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            mock_ai_instance.refine_itinerary.return_value = mock_refined_response
            mock_ai.return_value = mock_ai_instance
            
            complex_message = (
                "I want to make several changes: "
                "First, add the Eiffel Tower to Day 1. "
                "Second, replace the Louvre with a food tour on Day 2. "
                "Third, add more budget-friendly options throughout."
            )
            
            response = client_fixture.post(
                "/api/chat",
                json={
                    "trip_id": str(sample_trip.id),
                    "message": complex_message
                },
                headers=auth_headers
            )
            
            assert response.status_code == 200
            
            # Verify the full message was passed to AI
            mock_ai_instance.refine_itinerary.assert_called_once()
            call_args = mock_ai_instance.refine_itinerary.call_args[1]
            assert call_args["refinement_request"] == complex_message
