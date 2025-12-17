# app/api/chat.py
# Chat-based itinerary refinement endpoint

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import Optional
from pydantic import BaseModel, Field
from datetime import datetime

from ..core.database import get_session
from ..models.user import User
from ..models.trip import Trip, Day, Activity, TripResponse
from ..api.deps import CurrentUser
from ..services.ai_service import AIService


router = APIRouter()


class ChatRequest(BaseModel):
    """Request schema for chat refinement."""
    trip_id: str = Field(..., description="UUID of the trip to refine")
    message: str = Field(..., min_length=1, max_length=2000, description="User's refinement request")


class ChatResponse(BaseModel):
    """Response schema for chat refinement."""
    trip: TripResponse
    message: str = "Itinerary refined successfully"
    ai_response: Optional[str] = None


def _serialize_trip_for_context(trip: Trip, days: list, activities_by_day: dict) -> dict:
    """Serialize trip data for AI context."""
    days_data = []
    for day in days:
        day_activities = activities_by_day.get(day.id, [])
        days_data.append({
            "day_number": day.day_number,
            "date": day.date,
            "title": day.title,
            "activities": [
                {
                    "time": act.time,
                    "title": act.title,
                    "description": act.description,
                    "location": act.location,
                    "estimated_cost": act.estimated_cost,
                    "notes": act.notes,
                    "is_completed": act.is_completed
                }
                for act in day_activities
            ]
        })
    
    return {"days": days_data}


def _apply_refined_itinerary(
    trip: Trip,
    refined_data: dict,
    session: Session
) -> None:
    """Apply refined itinerary data to the database."""
    # Delete existing days and activities (CASCADE will handle activities)
    existing_days = session.exec(select(Day).where(Day.trip_id == trip.id)).all()
    for day in existing_days:
        session.delete(day)
    session.flush()
    
    # Create new days and activities from refined data
    for day_data in refined_data.get("days", []):
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
                is_completed=activity_data.get("is_completed", False)
            )
            session.add(activity)


@router.post("/chat", response_model=ChatResponse)
async def refine_itinerary(
    request: ChatRequest,
    current_user: CurrentUser,
    session: Session = Depends(get_session)
):
    """
    Refine an existing itinerary using conversational AI.
    
    This endpoint allows users to iteratively improve their generated itineraries
    by providing natural language feedback. The AI will understand the context
    and make appropriate modifications to the trip.
    
    **Request Body:**
    - `trip_id`: UUID of the trip to refine (must belong to current user)
    - `message`: Natural language refinement request
    
    **Example Messages:**
    - "Add a visit to the Eiffel Tower on Day 2"
    - "Make Day 3 more budget-friendly"
    - "Replace the morning activity on Day 1 with something cultural"
    - "Add more food experiences throughout the trip"
    - "Make the itinerary more relaxed with fewer activities per day"
    
    **Response:**
    - Complete refined trip with updated days and activities
    - Success message
    - Optional AI explanation of changes
    
    **Example:**
    ```json
    {
      "trip_id": "123e4567-e89b-12d3-a456-426614174000",
      "message": "Make Day 2 focus more on museums and art galleries"
    }
    ```
    
    **Errors:**
    - 400: Invalid request or AI service error
    - 401: Not authenticated
    - 403: Trip doesn't belong to user
    - 404: Trip not found
    - 422: Validation error (invalid trip_id format, message too long)
    """
    try:
        # Fetch the trip
        trip = session.get(Trip, request.trip_id)
        
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found"
            )
        
        # Verify ownership
        if trip.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to modify this trip"
            )
        
        # Load current itinerary
        days = session.exec(
            select(Day)
            .where(Day.trip_id == trip.id)
            .order_by(Day.day_number)
        ).all()
        
        # Load activities for each day
        activities_by_day = {}
        for day in days:
            activities = session.exec(
                select(Activity)
                .where(Activity.day_id == day.id)
                .order_by(Activity.time)
            ).all()
            activities_by_day[day.id] = activities
        
        if not days:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot refine trip with no days. Generate an itinerary first."
            )
        
        # Serialize current itinerary for AI context
        current_itinerary = _serialize_trip_for_context(trip, days, activities_by_day)
        
        # Calculate number of days
        start_date = datetime.strptime(trip.start_date, "%Y-%m-%d")
        end_date = datetime.strptime(trip.end_date, "%Y-%m-%d")
        num_days = (end_date - start_date).days + 1
        
        # Build trip context
        trip_context = {
            "destination": trip.destination,
            "num_days": num_days,
            "budget": trip.budget,
            "travel_style": trip.preferences.get("travel_style") if trip.preferences else None,
            "budget_tier": trip.preferences.get("budget_tier") if trip.preferences else None,
            "interests": trip.preferences.get("interests") if trip.preferences else None
        }
        
        # Initialize AI service and refine itinerary
        ai_service = AIService()
        refined_data = ai_service.refine_itinerary(
            current_itinerary=current_itinerary,
            refinement_request=request.message,
            trip_context=trip_context
        )
        
        # Apply refined itinerary to database
        _apply_refined_itinerary(trip, refined_data, session)
        
        # Update trip's updated_at timestamp
        trip.local_updated_at = datetime.utcnow()
        session.add(trip)
        
        session.commit()
        session.refresh(trip)
        
        # Build response with nested data
        from ..api.trips import _build_trip_response
        trip_response = _build_trip_response(trip, session)
        
        return ChatResponse(
            trip=trip_response,
            message="Itinerary refined based on your request",
            ai_response=f"I've updated your {trip.destination} itinerary based on: '{request.message}'"
        )
    
    except ValueError as e:
        # AI service errors
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        # Unexpected errors
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to refine itinerary: {str(e)}"
        )


@router.get("/chat/suggestions/{trip_id}")
async def get_refinement_suggestions(
    trip_id: str,
    current_user: CurrentUser,
    session: Session = Depends(get_session)
):
    """
    Get AI-suggested refinement ideas for a trip.
    
    Returns contextual suggestions based on the current itinerary,
    such as adding activities, adjusting pacing, or budget optimization.
    
    **Example Response:**
    ```json
    {
      "suggestions": [
        "Add more local food experiences",
        "Include a rest day in the middle of the trip",
        "Visit a lesser-known attraction on Day 3",
        "Add sunset viewing activities"
      ]
    }
    ```
    """
    # Fetch the trip
    trip = session.get(Trip, trip_id)
    
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    # Verify ownership
    if trip.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this trip"
        )
    
    # Load days to analyze
    days = session.exec(
        select(Day).where(Day.trip_id == trip.id)
    ).all()
    
    # Generate contextual suggestions based on trip characteristics
    suggestions = []
    
    # Budget-based suggestions
    budget_tier = trip.preferences.get("budget_tier") if trip.preferences else None
    if budget_tier == "budget":
        suggestions.append("Find free walking tours in your destination")
        suggestions.append("Add more street food experiences for authentic local cuisine")
    elif budget_tier == "luxury":
        suggestions.append("Consider adding a spa day or wellness experience")
        suggestions.append("Look into private guided tours for a more exclusive experience")
    
    # Duration-based suggestions
    num_days = len(days)
    if num_days >= 5:
        suggestions.append("Consider adding a rest day or half-day in the middle of the trip")
    if num_days >= 7:
        suggestions.append("Think about a day trip to a nearby town or attraction")
    
    # Travel style suggestions
    travel_style = trip.preferences.get("travel_style") if trip.preferences else None
    if travel_style == "adventure":
        suggestions.append("Add an outdoor activity like hiking or water sports")
    elif travel_style == "cultural":
        suggestions.append("Include a local cooking class or cultural workshop")
    elif travel_style == "foodie":
        suggestions.append("Add a food market tour or wine tasting experience")
    
    # General suggestions
    suggestions.extend([
        "Add sunset or sunrise viewing spots for memorable moments",
        "Include time for spontaneous exploration and local discoveries",
        "Consider the best photo opportunities for each location",
        "Add backup indoor activities in case of bad weather"
    ])
    
    return {
        "trip_id": trip_id,
        "destination": trip.destination,
        "suggestions": suggestions[:8]  # Limit to 8 suggestions
    }
