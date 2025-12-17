# app/models/trip.py
# Trip and related database models

from datetime import datetime
from typing import Optional, List
from uuid import UUID, uuid4
from sqlmodel import Field, SQLModel, Relationship, JSON, Column
from sqlalchemy import Text


class BudgetItem(SQLModel, table=True):
    """Budget item model."""
    
    __tablename__ = "budget_items"
    
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    trip_id: UUID = Field(foreign_key="trips.id", index=True, ondelete="CASCADE")
    category: str = Field(max_length=100)
    amount: float
    note: Optional[str] = Field(default=None, sa_column=Column(Text))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Sync fields
    server_id: Optional[UUID] = Field(default=None, index=True)
    is_synced: bool = Field(default=False)
    local_updated_at: datetime = Field(default_factory=datetime.utcnow)


class Note(SQLModel, table=True):
    """Note model for user notes on trips."""
    
    __tablename__ = "notes"
    
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    trip_id: UUID = Field(foreign_key="trips.id", index=True, ondelete="CASCADE")
    content: str = Field(sa_column=Column(Text))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Sync fields
    server_id: Optional[UUID] = Field(default=None, index=True)
    is_synced: bool = Field(default=False)
    local_updated_at: datetime = Field(default_factory=datetime.utcnow)


class Activity(SQLModel, table=True):
    """Activity model for trip activities."""
    
    __tablename__ = "activities"
    
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    day_id: UUID = Field(foreign_key="days.id", index=True, ondelete="CASCADE")
    time: str = Field(max_length=50)
    title: str = Field(max_length=255)
    description: str = Field(sa_column=Column(Text))
    location: Optional[str] = Field(default=None, max_length=255)
    estimated_cost: Optional[float] = Field(default=None)
    notes: Optional[str] = Field(default=None, sa_column=Column(Text))
    is_completed: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Sync fields
    server_id: Optional[UUID] = Field(default=None, index=True)
    is_synced: bool = Field(default=False)
    local_updated_at: datetime = Field(default_factory=datetime.utcnow)


class Day(SQLModel, table=True):
    """Day model for trip days."""
    
    __tablename__ = "days"
    
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    trip_id: UUID = Field(foreign_key="trips.id", index=True, ondelete="CASCADE")
    day_number: int
    date: str = Field(max_length=50)
    title: Optional[str] = Field(default=None, max_length=255)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Sync fields
    server_id: Optional[UUID] = Field(default=None, index=True)
    is_synced: bool = Field(default=False)
    local_updated_at: datetime = Field(default_factory=datetime.utcnow)


class Trip(SQLModel, table=True):
    """Trip model for user trips."""
    
    __tablename__ = "trips"
    
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id", index=True, ondelete="CASCADE")
    title: str = Field(max_length=255)
    destination: str = Field(max_length=255)
    start_date: str = Field(max_length=50)
    end_date: str = Field(max_length=50)
    budget: Optional[float] = Field(default=None)
    budget_tier: Optional[str] = Field(default=None, max_length=50)
    travel_style: Optional[str] = Field(default=None, max_length=50)
    interests: Optional[List[str]] = Field(default=None, sa_column=Column(JSON))
    special_requirements: Optional[str] = Field(default=None, sa_column=Column(Text))
    is_generated: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Sync fields
    server_id: Optional[UUID] = Field(default=None, index=True)
    is_synced: bool = Field(default=False)
    local_updated_at: datetime = Field(default_factory=datetime.utcnow)


# Response schemas with nested data
class ActivityResponse(SQLModel):
    """Activity response schema."""
    id: UUID
    time: str
    title: str
    description: str
    location: Optional[str]
    estimated_cost: Optional[float]
    notes: Optional[str]
    is_completed: bool
    server_id: Optional[UUID]
    is_synced: bool
    local_updated_at: datetime


class DayResponse(SQLModel):
    """Day response schema with activities."""
    id: UUID
    day_number: int
    date: str
    title: Optional[str]
    activities: List[ActivityResponse] = []
    server_id: Optional[UUID]
    is_synced: bool
    local_updated_at: datetime


class BudgetItemResponse(SQLModel):
    """Budget item response schema."""
    id: UUID
    category: str
    amount: float
    note: Optional[str]
    server_id: Optional[UUID]
    is_synced: bool
    local_updated_at: datetime


class NoteResponse(SQLModel):
    """Note response schema."""
    id: UUID
    content: str
    created_at: datetime
    server_id: Optional[UUID]
    is_synced: bool
    local_updated_at: datetime


class TripResponse(SQLModel):
    """Trip response schema with all nested data."""
    id: UUID
    title: str
    destination: str
    start_date: str
    end_date: str
    budget: Optional[float]
    budget_tier: Optional[str]
    travel_style: Optional[str]
    interests: Optional[List[str]]
    special_requirements: Optional[str]
    is_generated: bool
    created_at: datetime
    updated_at: datetime
    days: List[DayResponse] = []
    budget_items: List[BudgetItemResponse] = []
    notes: List[NoteResponse] = []
    server_id: Optional[UUID]
    is_synced: bool
    local_updated_at: datetime


class TripCreate(SQLModel):
    """Schema for creating a trip."""
    title: str
    destination: str
    start_date: str
    end_date: str
    budget: Optional[float] = None
    budget_tier: Optional[str] = None
    travel_style: Optional[str] = None
    interests: Optional[List[str]] = None
    special_requirements: Optional[str] = None


class TripUpdate(SQLModel):
    """Schema for updating a trip."""
    title: Optional[str] = None
    destination: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    budget: Optional[float] = None
    budget_tier: Optional[str] = None
    travel_style: Optional[str] = None
    interests: Optional[List[str]] = None
    special_requirements: Optional[str] = None
