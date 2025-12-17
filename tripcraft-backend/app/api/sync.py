# app/api/sync.py
# Bidirectional sync endpoints with conflict resolution

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List, Optional, Dict, Any, Literal
from pydantic import BaseModel, Field
from datetime import datetime
import uuid

from ..core.database import get_session
from ..models.user import User
from ..models.trip import Trip, Day, Activity, BudgetItem, Note
from ..api.deps import CurrentUser


router = APIRouter()


# Sync request/response schemas
class SyncEntity(BaseModel):
    """Base schema for entities in sync request."""
    id: str
    local_updated_at: str
    is_deleted: bool = False


class TripSyncData(SyncEntity):
    """Trip data for sync."""
    title: Optional[str] = None
    destination: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    budget: Optional[float] = None
    preferences: Optional[Dict[str, Any]] = None
    is_generated: Optional[bool] = None


class DaySyncData(SyncEntity):
    """Day data for sync."""
    trip_id: str
    day_number: Optional[int] = None
    date: Optional[str] = None
    title: Optional[str] = None


class ActivitySyncData(SyncEntity):
    """Activity data for sync."""
    day_id: str
    time: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    location: Optional[str] = None
    estimated_cost: Optional[float] = None
    notes: Optional[str] = None
    is_completed: Optional[bool] = None


class BudgetItemSyncData(SyncEntity):
    """Budget item data for sync."""
    trip_id: str
    category: Optional[str] = None
    amount: Optional[float] = None
    note: Optional[str] = None


class NoteSyncData(SyncEntity):
    """Note data for sync."""
    trip_id: str
    content: Optional[str] = None


class SyncRequest(BaseModel):
    """Request schema for sync operation."""
    last_sync_at: Optional[str] = Field(None, description="Last successful sync timestamp (ISO format)")
    conflict_resolution: Literal["server_wins", "client_wins", "newer_wins", "merge"] = Field(
        default="newer_wins",
        description="Strategy for resolving conflicts"
    )
    trips: List[TripSyncData] = Field(default_factory=list)
    days: List[DaySyncData] = Field(default_factory=list)
    activities: List[ActivitySyncData] = Field(default_factory=list)
    budget_items: List[BudgetItemSyncData] = Field(default_factory=list)
    notes: List[NoteSyncData] = Field(default_factory=list)


class SyncConflict(BaseModel):
    """Conflict information."""
    entity_type: str
    entity_id: str
    client_updated_at: str
    server_updated_at: str
    resolution: str


class SyncResponse(BaseModel):
    """Response schema for sync operation."""
    sync_timestamp: str
    trips_uploaded: int = 0
    trips_downloaded: int = 0
    days_uploaded: int = 0
    days_downloaded: int = 0
    activities_uploaded: int = 0
    activities_downloaded: int = 0
    budget_items_uploaded: int = 0
    budget_items_downloaded: int = 0
    notes_uploaded: int = 0
    notes_downloaded: int = 0
    conflicts_resolved: int = 0
    conflicts: List[SyncConflict] = Field(default_factory=list)
    server_data: Dict[str, List[Dict[str, Any]]] = Field(default_factory=dict)


def _parse_timestamp(ts_str: str) -> datetime:
    """Parse ISO timestamp string to datetime."""
    try:
        # Handle various ISO formats
        if 'T' in ts_str:
            if ts_str.endswith('Z'):
                return datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
            return datetime.fromisoformat(ts_str)
        return datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
    except Exception:
        return datetime.utcnow()


def _should_update(
    client_timestamp: str,
    server_timestamp: Optional[datetime],
    strategy: str
) -> bool:
    """Determine if client data should overwrite server data."""
    if not server_timestamp:
        return True
    
    client_dt = _parse_timestamp(client_timestamp)
    
    if strategy == "client_wins":
        return True
    elif strategy == "server_wins":
        return False
    elif strategy == "newer_wins":
        return client_dt > server_timestamp
    elif strategy == "merge":
        # For merge, we prefer newer data
        return client_dt > server_timestamp
    
    return False


def _serialize_trip(trip: Trip) -> Dict[str, Any]:
    """Serialize trip for sync response."""
    return {
        "id": str(trip.id),
        "title": trip.title,
        "destination": trip.destination,
        "start_date": trip.start_date,
        "end_date": trip.end_date,
        "budget": trip.budget,
        "preferences": trip.preferences or {},
        "is_generated": trip.is_generated,
        "server_id": trip.server_id,
        "is_synced": trip.is_synced,
        "local_updated_at": trip.local_updated_at.isoformat() if trip.local_updated_at else None,
        "created_at": trip.created_at.isoformat() if trip.created_at else None
    }


def _serialize_day(day: Day) -> Dict[str, Any]:
    """Serialize day for sync response."""
    return {
        "id": str(day.id),
        "trip_id": str(day.trip_id),
        "day_number": day.day_number,
        "date": day.date,
        "title": day.title,
        "server_id": day.server_id,
        "is_synced": day.is_synced,
        "local_updated_at": day.local_updated_at.isoformat() if day.local_updated_at else None
    }


def _serialize_activity(activity: Activity) -> Dict[str, Any]:
    """Serialize activity for sync response."""
    return {
        "id": str(activity.id),
        "day_id": str(activity.day_id),
        "time": activity.time,
        "title": activity.title,
        "description": activity.description,
        "location": activity.location,
        "estimated_cost": activity.estimated_cost,
        "notes": activity.notes,
        "is_completed": activity.is_completed,
        "server_id": activity.server_id,
        "is_synced": activity.is_synced,
        "local_updated_at": activity.local_updated_at.isoformat() if activity.local_updated_at else None
    }


def _serialize_budget_item(item: BudgetItem) -> Dict[str, Any]:
    """Serialize budget item for sync response."""
    return {
        "id": str(item.id),
        "trip_id": str(item.trip_id),
        "category": item.category,
        "amount": item.amount,
        "note": item.note,
        "server_id": item.server_id,
        "is_synced": item.is_synced,
        "local_updated_at": item.local_updated_at.isoformat() if item.local_updated_at else None
    }


def _serialize_note(note: Note) -> Dict[str, Any]:
    """Serialize note for sync response."""
    return {
        "id": str(note.id),
        "trip_id": str(note.trip_id),
        "content": note.content,
        "server_id": note.server_id,
        "is_synced": note.is_synced,
        "local_updated_at": note.local_updated_at.isoformat() if note.local_updated_at else None,
        "created_at": note.created_at.isoformat() if note.created_at else None
    }


@router.post("/sync", response_model=SyncResponse)
async def sync_data(
    request: SyncRequest,
    current_user: CurrentUser,
    session: Session = Depends(get_session)
):
    """
    Bidirectional sync endpoint with conflict resolution.
    
    This endpoint handles synchronization between client and server:
    1. Receives client changes (trips, days, activities, budget items, notes)
    2. Applies changes to server with conflict resolution
    3. Returns server changes since last sync
    
    **Conflict Resolution Strategies:**
    - `server_wins`: Server data always takes precedence
    - `client_wins`: Client data always takes precedence
    - `newer_wins`: Most recently updated data wins (default)
    - `merge`: Intelligent merge of both versions (uses newer_wins logic)
    
    **Request Body:**
    ```json
    {
      "last_sync_at": "2024-01-15T10:30:00Z",
      "conflict_resolution": "newer_wins",
      "trips": [...],
      "days": [...],
      "activities": [...],
      "budget_items": [...],
      "notes": [...]
    }
    ```
    
    **Response:**
    - Sync statistics (uploaded/downloaded counts)
    - Conflicts resolved with details
    - Server data to download (changes since last_sync_at)
    - New sync timestamp for next sync
    
    **Example Usage:**
    1. Client collects local changes since last sync
    2. Client sends changes to server
    3. Server applies changes with conflict resolution
    4. Server returns changes made by other devices
    5. Client applies server changes locally
    6. Client saves new sync timestamp
    """
    response = SyncResponse(
        sync_timestamp=datetime.utcnow().isoformat(),
        server_data={
            "trips": [],
            "days": [],
            "activities": [],
            "budget_items": [],
            "notes": []
        }
    )
    
    conflicts: List[SyncConflict] = []
    last_sync = _parse_timestamp(request.last_sync_at) if request.last_sync_at else None
    
    # Process client trips (upload)
    for trip_data in request.trips:
        try:
            trip = session.get(Trip, trip_data.id)
            
            if trip_data.is_deleted:
                # Delete trip
                if trip and trip.user_id == current_user.id:
                    session.delete(trip)
                    response.trips_uploaded += 1
                continue
            
            if trip:
                # Update existing trip
                if trip.user_id != current_user.id:
                    continue  # Skip unauthorized trips
                
                should_update = _should_update(
                    trip_data.local_updated_at,
                    trip.local_updated_at,
                    request.conflict_resolution
                )
                
                if not should_update:
                    conflicts.append(SyncConflict(
                        entity_type="trip",
                        entity_id=trip_data.id,
                        client_updated_at=trip_data.local_updated_at,
                        server_updated_at=trip.local_updated_at.isoformat() if trip.local_updated_at else "",
                        resolution="server_wins"
                    ))
                    continue
                
                # Apply updates
                if trip_data.title is not None:
                    trip.title = trip_data.title
                if trip_data.destination is not None:
                    trip.destination = trip_data.destination
                if trip_data.start_date is not None:
                    trip.start_date = trip_data.start_date
                if trip_data.end_date is not None:
                    trip.end_date = trip_data.end_date
                if trip_data.budget is not None:
                    trip.budget = trip_data.budget
                if trip_data.preferences is not None:
                    trip.preferences = trip_data.preferences
                if trip_data.is_generated is not None:
                    trip.is_generated = trip_data.is_generated
                
                trip.local_updated_at = _parse_timestamp(trip_data.local_updated_at)
                trip.is_synced = True
                session.add(trip)
                response.trips_uploaded += 1
            else:
                # Create new trip
                trip = Trip(
                    id=uuid.UUID(trip_data.id),
                    user_id=current_user.id,
                    title=trip_data.title or "Untitled Trip",
                    destination=trip_data.destination or "",
                    start_date=trip_data.start_date or datetime.utcnow().strftime("%Y-%m-%d"),
                    end_date=trip_data.end_date or datetime.utcnow().strftime("%Y-%m-%d"),
                    budget=trip_data.budget,
                    preferences=trip_data.preferences or {},
                    is_generated=trip_data.is_generated or False,
                    local_updated_at=_parse_timestamp(trip_data.local_updated_at),
                    is_synced=True
                )
                session.add(trip)
                response.trips_uploaded += 1
        
        except Exception as e:
            print(f"Error syncing trip {trip_data.id}: {e}")
            continue
    
    # Process client days
    for day_data in request.days:
        try:
            day = session.get(Day, day_data.id)
            
            if day_data.is_deleted:
                if day:
                    # Verify trip ownership
                    trip = session.get(Trip, day.trip_id)
                    if trip and trip.user_id == current_user.id:
                        session.delete(day)
                        response.days_uploaded += 1
                continue
            
            if day:
                # Verify ownership
                trip = session.get(Trip, day.trip_id)
                if not trip or trip.user_id != current_user.id:
                    continue
                
                should_update = _should_update(
                    day_data.local_updated_at,
                    day.local_updated_at,
                    request.conflict_resolution
                )
                
                if should_update:
                    if day_data.day_number is not None:
                        day.day_number = day_data.day_number
                    if day_data.date is not None:
                        day.date = day_data.date
                    if day_data.title is not None:
                        day.title = day_data.title
                    day.local_updated_at = _parse_timestamp(day_data.local_updated_at)
                    day.is_synced = True
                    session.add(day)
                    response.days_uploaded += 1
            else:
                # Create new day
                trip = session.get(Trip, day_data.trip_id)
                if trip and trip.user_id == current_user.id:
                    day = Day(
                        id=uuid.UUID(day_data.id),
                        trip_id=uuid.UUID(day_data.trip_id),
                        day_number=day_data.day_number or 1,
                        date=day_data.date or "",
                        title=day_data.title or "",
                        local_updated_at=_parse_timestamp(day_data.local_updated_at),
                        is_synced=True
                    )
                    session.add(day)
                    response.days_uploaded += 1
        
        except Exception as e:
            print(f"Error syncing day {day_data.id}: {e}")
            continue
    
    # Process client activities
    for activity_data in request.activities:
        try:
            activity = session.get(Activity, activity_data.id)
            
            if activity_data.is_deleted:
                if activity:
                    # Verify ownership through day->trip
                    day = session.get(Day, activity.day_id)
                    if day:
                        trip = session.get(Trip, day.trip_id)
                        if trip and trip.user_id == current_user.id:
                            session.delete(activity)
                            response.activities_uploaded += 1
                continue
            
            if activity:
                # Verify ownership
                day = session.get(Day, activity.day_id)
                if day:
                    trip = session.get(Trip, day.trip_id)
                    if not trip or trip.user_id != current_user.id:
                        continue
                
                should_update = _should_update(
                    activity_data.local_updated_at,
                    activity.local_updated_at,
                    request.conflict_resolution
                )
                
                if should_update:
                    if activity_data.time is not None:
                        activity.time = activity_data.time
                    if activity_data.title is not None:
                        activity.title = activity_data.title
                    if activity_data.description is not None:
                        activity.description = activity_data.description
                    if activity_data.location is not None:
                        activity.location = activity_data.location
                    if activity_data.estimated_cost is not None:
                        activity.estimated_cost = activity_data.estimated_cost
                    if activity_data.notes is not None:
                        activity.notes = activity_data.notes
                    if activity_data.is_completed is not None:
                        activity.is_completed = activity_data.is_completed
                    activity.local_updated_at = _parse_timestamp(activity_data.local_updated_at)
                    activity.is_synced = True
                    session.add(activity)
                    response.activities_uploaded += 1
            else:
                # Create new activity
                day = session.get(Day, activity_data.day_id)
                if day:
                    trip = session.get(Trip, day.trip_id)
                    if trip and trip.user_id == current_user.id:
                        activity = Activity(
                            id=uuid.UUID(activity_data.id),
                            day_id=uuid.UUID(activity_data.day_id),
                            time=activity_data.time,
                            title=activity_data.title or "",
                            description=activity_data.description,
                            location=activity_data.location,
                            estimated_cost=activity_data.estimated_cost or 0.0,
                            notes=activity_data.notes,
                            is_completed=activity_data.is_completed or False,
                            local_updated_at=_parse_timestamp(activity_data.local_updated_at),
                            is_synced=True
                        )
                        session.add(activity)
                        response.activities_uploaded += 1
        
        except Exception as e:
            print(f"Error syncing activity {activity_data.id}: {e}")
            continue
    
    # Process budget items
    for item_data in request.budget_items:
        try:
            item = session.get(BudgetItem, item_data.id)
            
            if item_data.is_deleted:
                if item:
                    trip = session.get(Trip, item.trip_id)
                    if trip and trip.user_id == current_user.id:
                        session.delete(item)
                        response.budget_items_uploaded += 1
                continue
            
            if item:
                trip = session.get(Trip, item.trip_id)
                if not trip or trip.user_id != current_user.id:
                    continue
                
                should_update = _should_update(
                    item_data.local_updated_at,
                    item.local_updated_at,
                    request.conflict_resolution
                )
                
                if should_update:
                    if item_data.category is not None:
                        item.category = item_data.category
                    if item_data.amount is not None:
                        item.amount = item_data.amount
                    if item_data.note is not None:
                        item.note = item_data.note
                    item.local_updated_at = _parse_timestamp(item_data.local_updated_at)
                    item.is_synced = True
                    session.add(item)
                    response.budget_items_uploaded += 1
            else:
                trip = session.get(Trip, item_data.trip_id)
                if trip and trip.user_id == current_user.id:
                    item = BudgetItem(
                        id=uuid.UUID(item_data.id),
                        trip_id=uuid.UUID(item_data.trip_id),
                        category=item_data.category or "",
                        amount=item_data.amount or 0.0,
                        note=item_data.note,
                        local_updated_at=_parse_timestamp(item_data.local_updated_at),
                        is_synced=True
                    )
                    session.add(item)
                    response.budget_items_uploaded += 1
        
        except Exception as e:
            print(f"Error syncing budget item {item_data.id}: {e}")
            continue
    
    # Process notes
    for note_data in request.notes:
        try:
            note = session.get(Note, note_data.id)
            
            if note_data.is_deleted:
                if note:
                    trip = session.get(Trip, note.trip_id)
                    if trip and trip.user_id == current_user.id:
                        session.delete(note)
                        response.notes_uploaded += 1
                continue
            
            if note:
                trip = session.get(Trip, note.trip_id)
                if not trip or trip.user_id != current_user.id:
                    continue
                
                should_update = _should_update(
                    note_data.local_updated_at,
                    note.local_updated_at,
                    request.conflict_resolution
                )
                
                if should_update:
                    if note_data.content is not None:
                        note.content = note_data.content
                    note.local_updated_at = _parse_timestamp(note_data.local_updated_at)
                    note.is_synced = True
                    session.add(note)
                    response.notes_uploaded += 1
            else:
                trip = session.get(Trip, note_data.trip_id)
                if trip and trip.user_id == current_user.id:
                    note = Note(
                        id=uuid.UUID(note_data.id),
                        trip_id=uuid.UUID(note_data.trip_id),
                        content=note_data.content or "",
                        local_updated_at=_parse_timestamp(note_data.local_updated_at),
                        is_synced=True
                    )
                    session.add(note)
                    response.notes_uploaded += 1
        
        except Exception as e:
            print(f"Error syncing note {note_data.id}: {e}")
            continue
    
    # Commit all changes
    session.commit()
    
    # Fetch server changes to download (changes since last_sync_at)
    if last_sync:
        # Get trips updated since last sync
        stmt = select(Trip).where(
            Trip.user_id == current_user.id,
            Trip.local_updated_at > last_sync
        )
        updated_trips = session.exec(stmt).all()
        response.server_data["trips"] = [_serialize_trip(t) for t in updated_trips]
        response.trips_downloaded = len(updated_trips)
        
        # Get all trip IDs for this user
        user_trip_ids = [t.id for t in session.exec(
            select(Trip).where(Trip.user_id == current_user.id)
        ).all()]
        
        if user_trip_ids:
            # Get days for user's trips updated since last sync
            stmt = select(Day).where(
                Day.trip_id.in_(user_trip_ids),
                Day.local_updated_at > last_sync
            )
            updated_days = session.exec(stmt).all()
            response.server_data["days"] = [_serialize_day(d) for d in updated_days]
            response.days_downloaded = len(updated_days)
            
            # Get day IDs
            user_day_ids = [d.id for d in session.exec(
                select(Day).where(Day.trip_id.in_(user_trip_ids))
            ).all()]
            
            if user_day_ids:
                # Get activities
                stmt = select(Activity).where(
                    Activity.day_id.in_(user_day_ids),
                    Activity.local_updated_at > last_sync
                )
                updated_activities = session.exec(stmt).all()
                response.server_data["activities"] = [_serialize_activity(a) for a in updated_activities]
                response.activities_downloaded = len(updated_activities)
            
            # Get budget items
            stmt = select(BudgetItem).where(
                BudgetItem.trip_id.in_(user_trip_ids),
                BudgetItem.local_updated_at > last_sync
            )
            updated_budget_items = session.exec(stmt).all()
            response.server_data["budget_items"] = [_serialize_budget_item(b) for b in updated_budget_items]
            response.budget_items_downloaded = len(updated_budget_items)
            
            # Get notes
            stmt = select(Note).where(
                Note.trip_id.in_(user_trip_ids),
                Note.local_updated_at > last_sync
            )
            updated_notes = session.exec(stmt).all()
            response.server_data["notes"] = [_serialize_note(n) for n in updated_notes]
            response.notes_downloaded = len(updated_notes)
    
    response.conflicts = conflicts
    response.conflicts_resolved = len(conflicts)
    
    return response
