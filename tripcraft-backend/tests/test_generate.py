# tests/test_generate.py
# Tests for AI itinerary generation endpoint

import pytest
from fastapi.testclient import TestClient as TC
from sqlmodel import Session, select
from unittest.mock import patch, MagicMock
import json

from app.main import app
from app.models.user import User
from app.models.trip import Trip, Day, Activity
from app.core.security import create_access_token


@pytest.fixture
def test_user(session_fixture: Session) -> User:
    """Create a test user."""
    user = User(
        email="generate@example.com",
        hashed_password="hashed_password",
        name="Test Generator"
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
def mock_ai_response():
    """Mock AI service response."""
    return {
        "days": [
            {
                "day_number": 1,
                "date": "2024-06-15",
                "title": "Day 1: Arrival in Tokyo",
                "activities": [
                    {
                        "time": "09:00 AM",
                        "title": "Arrive at Narita Airport",
                        "description": "Land at Narita International Airport and clear customs",
                        "location": "Narita International Airport",
                        "estimated_cost": 0.0,
                        "notes": "Exchange currency at airport"
                    },
                    {
                        "time": "11:30 AM",
                        "title": "Transfer to Hotel",
                        "description": "Take Narita Express train to central Tokyo",
                        "location": "Tokyo Station",
                        "estimated_cost": 35.0,
                        "notes": "Buy JR Pass if planning multiple train trips"
                    },
                    {
                        "time": "02:00 PM",
                        "title": "Check-in at Hotel",
                        "description": "Check into your accommodation in Shibuya",
                        "location": "Shibuya Hotel",
                        "estimated_cost": 150.0,
                        "notes": "Early check-in may require extra fee"
                    },
                    {
                        "time": "04:00 PM",
                        "title": "Explore Shibuya Crossing",
                        "description": "Visit the famous Shibuya Crossing and Hachiko statue",
                        "location": "Shibuya Crossing",
                        "estimated_cost": 0.0,
                        "notes": "Best viewed from Starbucks 2nd floor"
                    },
                    {
                        "time": "07:00 PM",
                        "title": "Dinner at Ichiran Ramen",
                        "description": "Try authentic Japanese ramen at famous chain",
                        "location": "Ichiran Shibuya",
                        "estimated_cost": 12.0,
                        "notes": "Order from vending machine outside"
                    }
                ]
            },
            {
                "day_number": 2,
                "date": "2024-06-16",
                "title": "Day 2: Cultural Tokyo",
                "activities": [
                    {
                        "time": "08:00 AM",
                        "title": "Breakfast at Hotel",
                        "description": "Traditional Japanese breakfast",
                        "location": "Hotel Restaurant",
                        "estimated_cost": 15.0
                    },
                    {
                        "time": "09:30 AM",
                        "title": "Visit Senso-ji Temple",
                        "description": "Explore Tokyo's oldest Buddhist temple",
                        "location": "Senso-ji Temple, Asakusa",
                        "estimated_cost": 0.0,
                        "notes": "Free entry, arrive early to avoid crowds"
                    },
                    {
                        "time": "12:00 PM",
                        "title": "Lunch at Nakamise Shopping Street",
                        "description": "Try street food and local snacks",
                        "location": "Nakamise Street",
                        "estimated_cost": 20.0
                    },
                    {
                        "time": "02:00 PM",
                        "title": "Tokyo Skytree",
                        "description": "Visit observation deck for panoramic views",
                        "location": "Tokyo Skytree",
                        "estimated_cost": 25.0,
                        "notes": "Book tickets online to skip queue"
                    },
                    {
                        "time": "06:00 PM",
                        "title": "Akihabara Electric Town",
                        "description": "Explore anime and electronics district",
                        "location": "Akihabara",
                        "estimated_cost": 50.0,
                        "notes": "Great for anime merchandise and arcade games"
                    }
                ]
            },
            {
                "day_number": 3,
                "date": "2024-06-17",
                "title": "Day 3: Modern Tokyo",
                "activities": [
                    {
                        "time": "09:00 AM",
                        "title": "TeamLab Borderless",
                        "description": "Interactive digital art museum",
                        "location": "teamLab Borderless, Odaiba",
                        "estimated_cost": 30.0,
                        "notes": "Book tickets in advance, highly popular"
                    },
                    {
                        "time": "12:30 PM",
                        "title": "Lunch at Odaiba",
                        "description": "Waterfront dining with view",
                        "location": "Aqua City Odaiba",
                        "estimated_cost": 25.0
                    },
                    {
                        "time": "02:30 PM",
                        "title": "Harajuku & Takeshita Street",
                        "description": "Explore trendy fashion district",
                        "location": "Harajuku",
                        "estimated_cost": 40.0,
                        "notes": "Try crepes and unique fashion stores"
                    },
                    {
                        "time": "05:00 PM",
                        "title": "Meiji Shrine",
                        "description": "Peaceful Shinto shrine in forest",
                        "location": "Meiji Shrine",
                        "estimated_cost": 0.0
                    },
                    {
                        "time": "07:30 PM",
                        "title": "Farewell Dinner",
                        "description": "Special kaiseki dinner",
                        "location": "Shinjuku Restaurant",
                        "estimated_cost": 80.0
                    }
                ]
            }
        ]
    }


class TestGenerateItinerary:
    """Test suite for AI itinerary generation."""
    
    def test_generate_success(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        test_user: User,
        mock_ai_response: dict
    ):
        """Test successful itinerary generation."""
        with patch('app.api.generate.AIService') as mock_ai:
            # Mock AI service
            mock_ai_instance = MagicMock()
            mock_ai_instance.generate_itinerary.return_value = mock_ai_response
            mock_ai.return_value = mock_ai_instance
            
            # Generate request
            response = client_fixture.post(
                "/api/generate",
                json={
                    "destination": "Tokyo, Japan",
                    "start_date": "2024-06-15",
                    "end_date": "2024-06-17",
                    "budget": 1500.0,
                    "budget_tier": "moderate",
                    "travel_style": "cultural",
                    "interests": ["anime", "temples", "food"],
                    "title": "Tokyo Adventure"
                },
                headers=auth_headers
            )
            
            assert response.status_code == 201
            data = response.json()
            
            assert "trip" in data
            assert "message" in data
            assert data["message"] == "Generated 3-day itinerary for Tokyo, Japan"
            
            trip = data["trip"]
            assert trip["title"] == "Tokyo Adventure"
            assert trip["destination"] == "Tokyo, Japan"
            assert trip["start_date"] == "2024-06-15"
            assert trip["end_date"] == "2024-06-17"
            assert trip["budget"] == 1500.0
            assert trip["is_generated"] is True
            
            # Check preferences
            prefs = trip["preferences"]
            assert prefs["budget_tier"] == "moderate"
            assert prefs["travel_style"] == "cultural"
            assert prefs["interests"] == ["anime", "temples", "food"]
            
            # Check days
            assert len(trip["days"]) == 3
            
            day1 = trip["days"][0]
            assert day1["day_number"] == 1
            assert day1["date"] == "2024-06-15"
            assert day1["title"] == "Day 1: Arrival in Tokyo"
            assert len(day1["activities"]) == 5
            
            # Check activities
            activity1 = day1["activities"][0]
            assert activity1["time"] == "09:00 AM"
            assert activity1["title"] == "Arrive at Narita Airport"
            assert activity1["location"] == "Narita International Airport"
            assert activity1["estimated_cost"] == 0.0
            assert activity1["is_completed"] is False
            
            # Verify database records
            trips = session_fixture.exec(
                select(Trip).where(Trip.user_id == test_user.id)
            ).all()
            assert len(trips) == 1
            
            db_trip = trips[0]
            assert db_trip.is_generated is True
            
            days = session_fixture.exec(
                select(Day).where(Day.trip_id == db_trip.id)
            ).all()
            assert len(days) == 3
            
            activities = session_fixture.exec(
                select(Activity).where(Activity.day_id.in_([d.id for d in days]))
            ).all()
            assert len(activities) == 15  # 5 + 5 + 5
    
    def test_generate_minimal_request(
        self,
        client_fixture,
        session_fixture: Session,
        auth_headers: dict,
        mock_ai_response: dict
    ):
        """Test generation with minimal required fields."""
        with patch('app.api.generate.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            mock_ai_instance.generate_itinerary.return_value = mock_ai_response
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/generate",
                json={
                    "destination": "Paris, France",
                    "start_date": "2024-06-15",
                    "end_date": "2024-06-17"
                },
                headers=auth_headers
            )
            
            assert response.status_code == 201
            data = response.json()
            
            trip = data["trip"]
            assert trip["title"] == "Paris, France Trip"  # Auto-generated title
            assert trip["budget"] is None
            assert trip["preferences"] == {}
    
    def test_generate_with_all_options(
        self,
        client_fixture,
        auth_headers: dict,
        mock_ai_response: dict
    ):
        """Test generation with all optional fields."""
        with patch('app.api.generate.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            mock_ai_instance.generate_itinerary.return_value = mock_ai_response
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/generate",
                json={
                    "destination": "Barcelona, Spain",
                    "start_date": "2024-06-15",
                    "end_date": "2024-06-17",
                    "budget": 2000.0,
                    "budget_tier": "luxury",
                    "travel_style": "foodie",
                    "interests": ["architecture", "beach", "tapas"],
                    "special_requirements": "Vegetarian meals only",
                    "title": "Barcelona Luxury Trip"
                },
                headers=auth_headers
            )
            
            assert response.status_code == 201
            data = response.json()
            trip = data["trip"]
            
            assert trip["preferences"]["special_requirements"] == "Vegetarian meals only"
            
            # Verify AI service was called with correct parameters
            mock_ai_instance.generate_itinerary.assert_called_once()
            call_args = mock_ai_instance.generate_itinerary.call_args[1]
            assert call_args["special_requirements"] == "Vegetarian meals only"
    
    def test_generate_no_auth(self, client_fixture):
        """Test generation without authentication."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "London, UK",
                "start_date": "2024-06-15",
                "end_date": "2024-06-17"
            }
        )
        
        assert response.status_code == 403
    
    def test_generate_invalid_dates_order(self, client_fixture, auth_headers: dict):
        """Test generation with end date before start date."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "Rome, Italy",
                "start_date": "2024-06-20",
                "end_date": "2024-06-15"  # Before start date
            },
            headers=auth_headers
        )
        
        assert response.status_code == 400
        assert "End date must be after start date" in response.json()["detail"]
    
    def test_generate_too_long_trip(self, client_fixture, auth_headers: dict):
        """Test generation with trip duration exceeding 14 days."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "Australia",
                "start_date": "2024-06-01",
                "end_date": "2024-06-20"  # 20 days
            },
            headers=auth_headers
        )
        
        assert response.status_code == 400
        assert "cannot exceed 14 days" in response.json()["detail"]
    
    def test_generate_invalid_date_format(self, client_fixture, auth_headers: dict):
        """Test generation with invalid date format."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "Berlin, Germany",
                "start_date": "15-06-2024",  # Wrong format
                "end_date": "2024-06-17"
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422  # Validation error
    
    def test_generate_invalid_budget_tier(self, client_fixture, auth_headers: dict):
        """Test generation with invalid budget tier."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "Madrid, Spain",
                "start_date": "2024-06-15",
                "end_date": "2024-06-17",
                "budget_tier": "super_expensive"  # Invalid
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422
    
    def test_generate_invalid_travel_style(self, client_fixture, auth_headers: dict):
        """Test generation with invalid travel style."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "Athens, Greece",
                "start_date": "2024-06-15",
                "end_date": "2024-06-17",
                "travel_style": "extreme_sports"  # Invalid
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422
    
    def test_generate_negative_budget(self, client_fixture, auth_headers: dict):
        """Test generation with negative budget."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "Vienna, Austria",
                "start_date": "2024-06-15",
                "end_date": "2024-06-17",
                "budget": -500.0  # Negative
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422
    
    def test_generate_ai_service_error(
        self,
        client_fixture,
        auth_headers: dict
    ):
        """Test generation when AI service fails."""
        with patch('app.api.generate.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            mock_ai_instance.generate_itinerary.side_effect = ValueError("Groq API error")
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/generate",
                json={
                    "destination": "Amsterdam, Netherlands",
                    "start_date": "2024-06-15",
                    "end_date": "2024-06-17"
                },
                headers=auth_headers
            )
            
            assert response.status_code == 400
            assert "Groq API error" in response.json()["detail"]
    
    def test_generate_malformed_ai_response(
        self,
        client_fixture,
        auth_headers: dict
    ):
        """Test generation with malformed AI response."""
        with patch('app.api.generate.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            # Return invalid structure (missing days)
            mock_ai_instance.generate_itinerary.return_value = {"invalid": "data"}
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/generate",
                json={
                    "destination": "Prague, Czech Republic",
                    "start_date": "2024-06-15",
                    "end_date": "2024-06-17"
                },
                headers=auth_headers
            )
            
            # Should fail during validation in AI service
            assert response.status_code in [400, 500]
    
    def test_generate_empty_destination(self, client_fixture, auth_headers: dict):
        """Test generation with empty destination."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "",
                "start_date": "2024-06-15",
                "end_date": "2024-06-17"
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422
    
    def test_generate_too_many_interests(self, client_fixture, auth_headers: dict):
        """Test generation with too many interests."""
        response = client_fixture.post(
            "/api/generate",
            json={
                "destination": "Stockholm, Sweden",
                "start_date": "2024-06-15",
                "end_date": "2024-06-17",
                "interests": ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k"]  # 11 items
            },
            headers=auth_headers
        )
        
        assert response.status_code == 422
    
    def test_generate_single_day_trip(
        self,
        client_fixture,
        auth_headers: dict
    ):
        """Test generation for single day trip."""
        mock_response = {
            "days": [
                {
                    "day_number": 1,
                    "date": "2024-06-15",
                    "title": "Day 1: Day Trip",
                    "activities": [
                        {
                            "time": "09:00 AM",
                            "title": "Morning Activity",
                            "description": "Start the day",
                            "location": "Location 1",
                            "estimated_cost": 20.0
                        },
                        {
                            "time": "02:00 PM",
                            "title": "Afternoon Activity",
                            "description": "Continue exploring",
                            "location": "Location 2",
                            "estimated_cost": 30.0
                        }
                    ]
                }
            ]
        }
        
        with patch('app.api.generate.AIService') as mock_ai:
            mock_ai_instance = MagicMock()
            mock_ai_instance.generate_itinerary.return_value = mock_response
            mock_ai.return_value = mock_ai_instance
            
            response = client_fixture.post(
                "/api/generate",
                json={
                    "destination": "Bruges, Belgium",
                    "start_date": "2024-06-15",
                    "end_date": "2024-06-15"  # Same day
                },
                headers=auth_headers
            )
            
            assert response.status_code == 201
            data = response.json()
            assert len(data["trip"]["days"]) == 1
            assert "1-day itinerary" in data["message"]
