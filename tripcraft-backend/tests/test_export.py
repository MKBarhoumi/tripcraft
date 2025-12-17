"""
Tests for PDF export endpoint
"""
import pytest
from fastapi.testclient import TestClient
from datetime import date, time
from unittest.mock import patch, MagicMock
import base64

from app.main import app
from app.models.user import User
from app.models.trip import Trip, Day, Activity, BudgetItem, Note, BudgetTier, TravelStyle, BudgetCategory


client = TestClient(app)


@pytest.fixture
def auth_headers(session):
    """Create a user and return auth headers."""
    user = User(
        email="test@example.com",
        username="testuser",
        hashed_password="$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYzNFJgZK3u"  # "password"
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    
    # Login
    response = client.post("/api/auth/login", json={
        "email": "test@example.com",
        "password": "password"
    })
    token = response.json()["access_token"]
    
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def sample_trip(session, auth_headers):
    """Create a sample trip with days and activities."""
    # Get user
    response = client.get("/api/auth/me", headers=auth_headers)
    user_id = response.json()["id"]
    
    # Create trip
    trip = Trip(
        user_id=user_id,
        destination="Paris, France",
        start_date=date(2024, 6, 1),
        end_date=date(2024, 6, 3),
        budget_amount=2000.0,
        budget_tier=BudgetTier.MODERATE,
        travel_style=TravelStyle.CULTURAL
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Create days
    day1 = Day(trip_id=trip.id, date=date(2024, 6, 1), day_number=1)
    day2 = Day(trip_id=trip.id, date=date(2024, 6, 2), day_number=2)
    session.add_all([day1, day2])
    session.commit()
    session.refresh(day1)
    session.refresh(day2)
    
    # Create activities
    activities = [
        Activity(
            day_id=day1.id,
            name="Visit Eiffel Tower",
            description="Iconic landmark with stunning views",
            location="Champ de Mars, Paris",
            time=time(9, 0),
            order_index=0
        ),
        Activity(
            day_id=day1.id,
            name="Lunch at Café de Flore",
            description="Historic Parisian café",
            location="172 Boulevard Saint-Germain",
            time=time(12, 30),
            order_index=1
        ),
        Activity(
            day_id=day2.id,
            name="Louvre Museum",
            description="World's largest art museum",
            location="Rue de Rivoli, Paris",
            time=time(10, 0),
            order_index=0
        )
    ]
    session.add_all(activities)
    
    # Create budget items
    budget_items = [
        BudgetItem(
            trip_id=trip.id,
            category=BudgetCategory.ACCOMMODATION,
            description="Hotel for 2 nights",
            amount=600.0
        ),
        BudgetItem(
            trip_id=trip.id,
            category=BudgetCategory.FOOD,
            description="Meals and dining",
            amount=400.0
        ),
        BudgetItem(
            trip_id=trip.id,
            category=BudgetCategory.ACTIVITIES,
            description="Museum tickets and tours",
            amount=200.0
        )
    ]
    session.add_all(budget_items)
    
    # Create notes
    notes = [
        Note(
            trip_id=trip.id,
            title="Travel Tips",
            content="Remember to book Eiffel Tower tickets in advance"
        ),
        Note(
            trip_id=trip.id,
            title="Packing",
            content="Bring comfortable walking shoes"
        )
    ]
    session.add_all(notes)
    
    session.commit()
    
    return trip


def test_export_trip_success(session, auth_headers, sample_trip):
    """Test successful trip export when Supabase is not configured."""
    response = client.post(
        f"/api/trips/{sample_trip.id}/export",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert data["success"] is True
    assert "filename" in data
    assert data["filename"].startswith(f"trip_{sample_trip.id}_")
    assert data["filename"].endswith(".pdf")
    assert data["size_bytes"] > 0
    
    # Since Supabase is not configured in test, should return base64
    assert "pdf_base64" in data
    assert data["pdf_base64"] is not None
    assert len(data["pdf_base64"]) > 0
    
    # Verify it's valid base64
    try:
        pdf_bytes = base64.b64decode(data["pdf_base64"])
        assert len(pdf_bytes) > 0
        # Check PDF magic number
        assert pdf_bytes[:4] == b'%PDF'
    except Exception as e:
        pytest.fail(f"Invalid base64 PDF: {e}")


def test_export_trip_not_found(session, auth_headers):
    """Test exporting a non-existent trip."""
    response = client.post(
        "/api/trips/99999/export",
        headers=auth_headers
    )
    
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


def test_export_trip_unauthorized(session, auth_headers, sample_trip):
    """Test exporting a trip owned by another user."""
    # Create another user
    user2 = User(
        email="other@example.com",
        username="otheruser",
        hashed_password="$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYzNFJgZK3u"
    )
    session.add(user2)
    session.commit()
    
    # Login as other user
    response = client.post("/api/auth/login", json={
        "email": "other@example.com",
        "password": "password"
    })
    other_token = response.json()["access_token"]
    other_headers = {"Authorization": f"Bearer {other_token}"}
    
    # Try to export first user's trip
    response = client.post(
        f"/api/trips/{sample_trip.id}/export",
        headers=other_headers
    )
    
    assert response.status_code == 403
    assert "not authorized" in response.json()["detail"].lower()


def test_export_trip_no_auth(session, sample_trip):
    """Test exporting without authentication."""
    response = client.post(f"/api/trips/{sample_trip.id}/export")
    
    assert response.status_code == 401


def test_export_minimal_trip(session, auth_headers):
    """Test exporting a trip with minimal data (no activities, budget, or notes)."""
    # Get user
    response = client.get("/api/auth/me", headers=auth_headers)
    user_id = response.json()["id"]
    
    # Create minimal trip
    trip = Trip(
        user_id=user_id,
        destination="London",
        start_date=date(2024, 7, 1),
        end_date=date(2024, 7, 1)  # Single day
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Export
    response = client.post(
        f"/api/trips/{trip.id}/export",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert data["success"] is True
    assert data["size_bytes"] > 0
    assert "pdf_base64" in data


def test_export_with_supabase_configured(session, auth_headers, sample_trip):
    """Test export with Supabase configured (mocked)."""
    # Mock Supabase client
    mock_supabase = MagicMock()
    mock_storage = MagicMock()
    mock_bucket = MagicMock()
    
    mock_supabase.storage.from_.return_value = mock_bucket
    mock_bucket.upload.return_value = {"path": "test/path.pdf"}
    mock_bucket.get_public_url.return_value = "https://example.com/test.pdf"
    
    # Mock environment variables
    with patch.dict('os.environ', {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_KEY': 'test-key',
        'SUPABASE_BUCKET': 'trip-exports'
    }):
        # Mock the Supabase client creation
        with patch('app.api.export.create_client', return_value=mock_supabase):
            response = client.post(
                f"/api/trips/{sample_trip.id}/export",
                headers=auth_headers
            )
    
    assert response.status_code == 200
    data = response.json()
    
    assert data["success"] is True
    assert data["download_url"] == "https://example.com/test.pdf"
    assert "storage_path" in data
    assert "pdf_base64" not in data


def test_export_supabase_upload_error(session, auth_headers, sample_trip):
    """Test handling of Supabase upload errors."""
    # Mock Supabase client that raises an error
    mock_supabase = MagicMock()
    mock_storage = MagicMock()
    mock_bucket = MagicMock()
    
    mock_supabase.storage.from_.return_value = mock_bucket
    mock_bucket.upload.side_effect = Exception("Upload failed")
    
    # Mock environment variables
    with patch.dict('os.environ', {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_KEY': 'test-key',
        'SUPABASE_BUCKET': 'trip-exports'
    }):
        # Mock the Supabase client creation
        with patch('app.api.export.create_client', return_value=mock_supabase):
            response = client.post(
                f"/api/trips/{sample_trip.id}/export",
                headers=auth_headers
            )
    
    assert response.status_code == 500
    assert "upload" in response.json()["detail"].lower()


def test_export_pdf_generation_error(session, auth_headers, sample_trip):
    """Test handling of PDF generation errors."""
    # Mock the PDF generation function to raise an error
    with patch('app.api.export.generate_trip_pdf', side_effect=Exception("PDF generation failed")):
        response = client.post(
            f"/api/trips/{sample_trip.id}/export",
            headers=auth_headers
        )
    
    assert response.status_code == 500
    assert "generate pdf" in response.json()["detail"].lower()


def test_export_reportlab_not_available(session, auth_headers, sample_trip):
    """Test behavior when ReportLab is not installed."""
    # Mock REPORTLAB_AVAILABLE as False
    with patch('app.api.export.REPORTLAB_AVAILABLE', False):
        response = client.post(
            f"/api/trips/{sample_trip.id}/export",
            headers=auth_headers
        )
    
    assert response.status_code == 503
    assert "unavailable" in response.json()["detail"].lower()


def test_export_with_all_data_types(session, auth_headers):
    """Test export with all possible data types and edge cases."""
    # Get user
    response = client.get("/api/auth/me", headers=auth_headers)
    user_id = response.json()["id"]
    
    # Create comprehensive trip
    trip = Trip(
        user_id=user_id,
        destination="Tokyo, Japan",
        start_date=date(2024, 8, 1),
        end_date=date(2024, 8, 5),
        budget_amount=5000.0,
        budget_tier=BudgetTier.LUXURY,
        travel_style=TravelStyle.ADVENTURE
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Create multiple days
    days = []
    for i in range(5):
        day = Day(
            trip_id=trip.id,
            date=date(2024, 8, 1 + i),
            day_number=i + 1
        )
        session.add(day)
        days.append(day)
    session.commit()
    
    # Create activities with various properties
    for day in days:
        session.refresh(day)
        for j in range(3):
            activity = Activity(
                day_id=day.id,
                name=f"Activity {j + 1}",
                description=f"Description for activity {j + 1}" if j % 2 == 0 else None,
                location=f"Location {j + 1}" if j % 2 == 1 else None,
                time=time(9 + j * 3, 0) if j < 2 else None,
                order_index=j
            )
            session.add(activity)
    
    # Create budget items for all categories
    for category in BudgetCategory:
        item = BudgetItem(
            trip_id=trip.id,
            category=category,
            description=f"{category.value} expense",
            amount=100.0 * (list(BudgetCategory).index(category) + 1)
        )
        session.add(item)
    
    # Create multiple notes
    for i in range(5):
        note = Note(
            trip_id=trip.id,
            title=f"Note {i + 1}" if i % 2 == 0 else None,
            content=f"Content for note {i + 1}"
        )
        session.add(note)
    
    session.commit()
    
    # Export
    response = client.post(
        f"/api/trips/{trip.id}/export",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    
    assert data["success"] is True
    assert data["size_bytes"] > 5000  # Should be a substantial PDF
    
    # Decode and verify PDF
    pdf_bytes = base64.b64decode(data["pdf_base64"])
    assert pdf_bytes[:4] == b'%PDF'


def test_export_trip_with_unicode_characters(session, auth_headers):
    """Test export with unicode characters in trip data."""
    # Get user
    response = client.get("/api/auth/me", headers=auth_headers)
    user_id = response.json()["id"]
    
    # Create trip with unicode
    trip = Trip(
        user_id=user_id,
        destination="北京 (Beijing), 中国",
        start_date=date(2024, 9, 1),
        end_date=date(2024, 9, 2)
    )
    session.add(trip)
    session.commit()
    session.refresh(trip)
    
    # Create day with unicode activity
    day = Day(trip_id=trip.id, date=date(2024, 9, 1), day_number=1)
    session.add(day)
    session.commit()
    session.refresh(day)
    
    activity = Activity(
        day_id=day.id,
        name="Visit 故宫 (Forbidden City)",
        description="探索中国历史 - Explore Chinese history",
        location="东城区景山前街4号",
        time=time(10, 0),
        order_index=0
    )
    session.add(activity)
    
    note = Note(
        trip_id=trip.id,
        title="语言提示",
        content="学习基本中文短语 🇨🇳"
    )
    session.add(note)
    
    session.commit()
    
    # Export
    response = client.post(
        f"/api/trips/{trip.id}/export",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True


def test_export_filename_format(session, auth_headers, sample_trip):
    """Test that export filename follows correct format."""
    response = client.post(
        f"/api/trips/{sample_trip.id}/export",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    
    filename = data["filename"]
    
    # Check format: trip_{id}_{timestamp}.pdf
    assert filename.startswith(f"trip_{sample_trip.id}_")
    assert filename.endswith(".pdf")
    
    # Extract timestamp part
    timestamp_part = filename.replace(f"trip_{sample_trip.id}_", "").replace(".pdf", "")
    
    # Should be in format YYYYMMDD_HHMMSS
    assert len(timestamp_part) == 15  # YYYYMMDD_HHMMSS
    assert timestamp_part[8] == "_"


def test_export_response_structure(session, auth_headers, sample_trip):
    """Test that export response has correct structure."""
    response = client.post(
        f"/api/trips/{sample_trip.id}/export",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    
    # Required fields
    assert "success" in data
    assert "filename" in data
    assert "size_bytes" in data
    
    # Should have either download_url (Supabase) or pdf_base64 (no Supabase)
    assert "download_url" in data or "pdf_base64" in data
    
    if data.get("download_url"):
        assert "storage_path" in data
    
    if data.get("pdf_base64"):
        assert "message" in data
