# app/api/generate.py
# AI itinerary generation endpoint

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
import uuid

from ..core.database import get_session
from ..models.user import User
from ..models.trip import Trip, Day, Activity, TripResponse
from ..api.deps import CurrentUser
from ..services.ai_service import AIService


router = APIRouter()


class GenerateRequest(BaseModel):
    """Request schema for itinerary generation."""
    destination: str = Field(..., min_length=1, max_length=200)
    start_date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    end_date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    budget: Optional[float] = Field(None, ge=0)
    budget_tier: Optional[str] = Field(None, pattern=r'^(budget|moderate|luxury)$')
    travel_style: Optional[str] = Field(None, pattern=r'^(relaxation|adventure|cultural|foodie|mixed)$')
    interests: Optional[List[str]] = Field(None, max_items=10)
    special_requirements: Optional[str] = Field(None, max_length=1000)
    title: Optional[str] = Field(None, max_length=200)


class GenerateResponse(BaseModel):
    """Response schema for generation."""
    trip: TripResponse
    message: str = "Itinerary generated successfully"


@router.post("/generate", response_model=GenerateResponse, status_code=status.HTTP_201_CREATED)
async def generate_itinerary(
    request: GenerateRequest,
    current_user: CurrentUser,
    session: Session = Depends(get_session)
):
    """
    Generate an AI-powered travel itinerary.
    
    This endpoint uses Groq AI (Mixtral model) to generate a complete day-by-day
    itinerary based on user preferences. It creates the trip, days, and activities
    in the database.
    
    **Request Body:**
    - `destination`: Travel destination (e.g., "Paris, France")
    - `start_date`: Trip start date in YYYY-MM-DD format
    - `end_date`: Trip end date in YYYY-MM-DD format
    - `budget`: Optional total budget in USD
    - `budget_tier`: Optional budget category (budget/moderate/luxury)
    - `travel_style`: Optional travel style (relaxation/adventure/cultural/foodie/mixed)
    - `interests`: Optional list of interests (e.g., ["art", "food", "history"])
    - `special_requirements`: Optional special needs or preferences
    - `title`: Optional custom trip title
    
    **Response:**
    - Complete trip with all generated days and activities
    - Each day contains 4-6 activities with times, locations, and costs
    
    **Example:**
    ```json
    {
      "destination": "Tokyo, Japan",
      "start_date": "2024-06-15",
      "end_date": "2024-06-20",
      "budget": 3000,
      "budget_tier": "moderate",
      "travel_style": "cultural",
      "interests": ["anime", "food", "temples"],
      "title": "Amazing Tokyo Adventure"
    }
    ```
    
    **Errors:**
    - 400: Invalid dates or generation failed
    - 401: Not authenticated
    - 500: AI service error
    """
    try:
        # Validate dates
        start = datetime.strptime(request.start_date, "%Y-%m-%d")
        end = datetime.strptime(request.end_date, "%Y-%m-%d")
        
        if end < start:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="End date must be after start date"
            )
        
        num_days = (end - start).days + 1
        
        if num_days > 14:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Trip duration cannot exceed 14 days"
            )
        
        # Initialize AI service
        ai_service = AIService()
        
        # Generate itinerary using Groq
        itinerary_data = ai_service.generate_itinerary(
            destination=request.destination,
            start_date=request.start_date,
            end_date=request.end_date,
            budget=request.budget,
            budget_tier=request.budget_tier,
            travel_style=request.travel_style,
            interests=request.interests,
            special_requirements=request.special_requirements
        )
        
        # Create trip
        trip_title = request.title or f"{request.destination} Trip"
        
        # Build preferences dict
        preferences = {}
        if request.budget_tier:
            preferences["budget_tier"] = request.budget_tier
        if request.travel_style:
            preferences["travel_style"] = request.travel_style
        if request.interests:
            preferences["interests"] = request.interests
        if request.special_requirements:
            preferences["special_requirements"] = request.special_requirements
        
        trip = Trip(
            user_id=current_user.id,
            title=trip_title,
            destination=request.destination,
            start_date=request.start_date,
            end_date=request.end_date,
            budget=request.budget,
            preferences=preferences,
            is_generated=True
        )
        
        session.add(trip)
        session.flush()  # Get trip.id
        
        # Create days and activities
        for day_data in itinerary_data.get("days", []):
            day = Day(
                trip_id=trip.id,
                day_number=day_data["day_number"],
                date=day_data["date"],
                title=day_data.get("title", f"Day {day_data['day_number']}")
            )
            session.add(day)
            session.flush()  # Get day.id
            
            # Create activities for this day
            for activity_data in day_data.get("activities", []):
                activity = Activity(
                    day_id=day.id,
                    time=activity_data.get("time"),
                    title=activity_data["title"],
                    description=activity_data.get("description"),
                    location=activity_data.get("location"),
                    estimated_cost=activity_data.get("estimated_cost", 0.0),
                    notes=activity_data.get("notes"),
                    is_completed=False
                )
                session.add(activity)
        
        session.commit()
        session.refresh(trip)
        
        # Build response with nested data
        from ..api.trips import _build_trip_response
        trip_response = _build_trip_response(trip, session)
        
        return GenerateResponse(
            trip=trip_response,
            message=f"Generated {num_days}-day itinerary for {request.destination}"
        )
    
    except ValueError as e:
        # AI service errors or validation errors
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        # Unexpected errors
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate itinerary: {str(e)}"
        )
