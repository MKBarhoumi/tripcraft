# app/api/trips.py
# Trip CRUD endpoints

from datetime import datetime
from typing import Annotated, Optional, List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select, or_, col

from ..core.database import get_session
from ..models.user import User
from ..models.trip import (
    Trip, Day, Activity, Note, BudgetItem,
    TripCreate, TripUpdate, TripResponse,
    DayResponse, ActivityResponse, NoteResponse, BudgetItemResponse
)
from .deps import CurrentUser

router = APIRouter()


def _build_trip_response(trip: Trip, session: Session) -> TripResponse:
    """
    Build a complete trip response with all nested data.
    
    Args:
        trip: Trip object
        session: Database session
    
    Returns:
        TripResponse with days, activities, budget items, and notes
    """
    # Get all days for this trip
    days_statement = select(Day).where(Day.trip_id == trip.id).order_by(Day.day_number)
    days = session.exec(days_statement).all()
    
    # Build days with activities
    days_response = []
    for day in days:
        activities_statement = select(Activity).where(Activity.day_id == day.id)
        activities = session.exec(activities_statement).all()
        
        activities_response = [
            ActivityResponse(
                id=activity.id,
                time=activity.time,
                title=activity.title,
                description=activity.description,
                location=activity.location,
                estimated_cost=activity.estimated_cost,
                notes=activity.notes,
                is_completed=activity.is_completed,
                server_id=activity.server_id,
                is_synced=activity.is_synced,
                local_updated_at=activity.local_updated_at
            )
            for activity in activities
        ]
        
        days_response.append(DayResponse(
            id=day.id,
            day_number=day.day_number,
            date=day.date,
            title=day.title,
            activities=activities_response,
            server_id=day.server_id,
            is_synced=day.is_synced,
            local_updated_at=day.local_updated_at
        ))
    
    # Get budget items
    budget_statement = select(BudgetItem).where(BudgetItem.trip_id == trip.id)
    budget_items = session.exec(budget_statement).all()
    budget_items_response = [
        BudgetItemResponse(
            id=item.id,
            category=item.category,
            amount=item.amount,
            note=item.note,
            server_id=item.server_id,
            is_synced=item.is_synced,
            local_updated_at=item.local_updated_at
        )
        for item in budget_items
    ]
    
    # Get notes
    notes_statement = select(Note).where(Note.trip_id == trip.id)
    notes = session.exec(notes_statement).all()
    notes_response = [
        NoteResponse(
            id=note.id,
            content=note.content,
            created_at=note.created_at,
            server_id=note.server_id,
            is_synced=note.is_synced,
            local_updated_at=note.local_updated_at
        )
        for note in notes
    ]
    
    return TripResponse(
        id=trip.id,
        title=trip.title,
        destination=trip.destination,
        start_date=trip.start_date,
        end_date=trip.end_date,
        budget=trip.budget,
        budget_tier=trip.budget_tier,
        travel_style=trip.travel_style,
        interests=trip.interests,
        special_requirements=trip.special_requirements,
        is_generated=trip.is_generated,
        created_at=trip.created_at,
        updated_at=trip.updated_at,
        days=days_response,
        budget_items=budget_items_response,
        notes=notes_response,
        server_id=trip.server_id,
        is_synced=trip.is_synced,
        local_updated_at=trip.local_updated_at
    )


@router.post("", response_model=TripResponse, status_code=status.HTTP_201_CREATED)
async def create_trip(
    trip_data: TripCreate,
    current_user: CurrentUser,
    session: Annotated[Session, Depends(get_session)]
):
    """
    Create a new trip for the current user.
    
    Args:
        trip_data: Trip creation data
        current_user: Current authenticated user
        session: Database session
    
    Returns:
        TripResponse with created trip data
    """
    # Create new trip
    new_trip = Trip(
        user_id=current_user.id,
        title=trip_data.title,
        destination=trip_data.destination,
        start_date=trip_data.start_date,
        end_date=trip_data.end_date,
        budget=trip_data.budget,
        budget_tier=trip_data.budget_tier,
        travel_style=trip_data.travel_style,
        interests=trip_data.interests,
        special_requirements=trip_data.special_requirements,
        is_generated=False
    )
    
    session.add(new_trip)
    session.commit()
    session.refresh(new_trip)
    
    return _build_trip_response(new_trip, session)


@router.get("", response_model=List[TripResponse])
async def list_trips(
    current_user: CurrentUser,
    session: Annotated[Session, Depends(get_session)],
    search: Optional[str] = Query(None, description="Search in title and destination"),
    destination: Optional[str] = Query(None, description="Filter by destination"),
    is_generated: Optional[bool] = Query(None, description="Filter by generated status"),
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=100, description="Max number of records to return")
):
    """
    List all trips for the current user with optional filtering.
    
    Args:
        current_user: Current authenticated user
        session: Database session
        search: Search term for title/destination
        destination: Filter by destination
        is_generated: Filter by generation status
        skip: Pagination offset
        limit: Pagination limit
    
    Returns:
        List of TripResponse objects
    """
    # Base query
    statement = select(Trip).where(Trip.user_id == current_user.id)
    
    # Apply filters
    if search:
        search_term = f"%{search}%"
        statement = statement.where(
            or_(
                col(Trip.title).ilike(search_term),
                col(Trip.destination).ilike(search_term)
            )
        )
    
    if destination:
        statement = statement.where(col(Trip.destination).ilike(f"%{destination}%"))
    
    if is_generated is not None:
        statement = statement.where(Trip.is_generated == is_generated)
    
    # Apply ordering and pagination
    statement = statement.order_by(Trip.created_at.desc()).offset(skip).limit(limit)
    
    trips = session.exec(statement).all()
    
    return [_build_trip_response(trip, session) for trip in trips]


@router.get("/{trip_id}", response_model=TripResponse)
async def get_trip(
    trip_id: UUID,
    current_user: CurrentUser,
    session: Annotated[Session, Depends(get_session)]
):
    """
    Get a single trip by ID.
    
    Args:
        trip_id: Trip UUID
        current_user: Current authenticated user
        session: Database session
    
    Returns:
        TripResponse with full trip data
    
    Raises:
        HTTPException 404: If trip not found or doesn't belong to user
    """
    statement = select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
    trip = session.exec(statement).first()
    
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    return _build_trip_response(trip, session)


@router.put("/{trip_id}", response_model=TripResponse)
async def update_trip(
    trip_id: UUID,
    trip_data: TripUpdate,
    current_user: CurrentUser,
    session: Annotated[Session, Depends(get_session)]
):
    """
    Update a trip.
    
    Args:
        trip_id: Trip UUID
        trip_data: Trip update data
        current_user: Current authenticated user
        session: Database session
    
    Returns:
        TripResponse with updated trip data
    
    Raises:
        HTTPException 404: If trip not found or doesn't belong to user
    """
    statement = select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
    trip = session.exec(statement).first()
    
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    # Update fields if provided
    update_data = trip_data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(trip, key, value)
    
    trip.updated_at = datetime.utcnow()
    trip.local_updated_at = datetime.utcnow()
    
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    return _build_trip_response(trip, session)


@router.delete("/{trip_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_trip(
    trip_id: UUID,
    current_user: CurrentUser,
    session: Annotated[Session, Depends(get_session)]
):
    """
    Delete a trip (and all related data via CASCADE).
    
    Args:
        trip_id: Trip UUID
        current_user: Current authenticated user
        session: Database session
    
    Returns:
        204 No Content on success
    
    Raises:
        HTTPException 404: If trip not found or doesn't belong to user
    """
    statement = select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
    trip = session.exec(statement).first()
    
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    session.delete(trip)
    session.commit()
    
    return None
