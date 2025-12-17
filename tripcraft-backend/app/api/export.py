"""
Export API Endpoints
Handles PDF export of trip itineraries to Supabase Storage.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from datetime import datetime
from typing import Optional
import io
import os

from app.core.config import settings
from app.core.database import get_session
from app.core.security import get_current_user
from app.models.user import User
from app.models.trip import Trip, Day, Activity, BudgetItem, Note

# Import PDF generation library
try:
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.lib import colors
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak
    from reportlab.pdfgen import canvas
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False

# Import Supabase client
try:
    from supabase import create_client, Client
    SUPABASE_AVAILABLE = True
except ImportError:
    SUPABASE_AVAILABLE = False

router = APIRouter()


# Supabase client initialization
def get_supabase_client() -> Optional[Client]:
    """Initialize Supabase client for storage."""
    if not SUPABASE_AVAILABLE:
        return None
    
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")
    
    if not url or not key or url == "https://your-project.supabase.co" or key == "your-supabase-anon-key":
        return None
    
    try:
        return create_client(url, key)
    except Exception:
        return None


def generate_trip_pdf(trip: Trip, days: list[Day], activities: list[Activity], 
                      budget_items: list[BudgetItem], notes: list[Note]) -> bytes:
    """
    Generate a formatted PDF for a trip itinerary.
    
    Args:
        trip: The trip object
        days: List of days in the trip
        activities: List of activities
        budget_items: List of budget items
        notes: List of notes
    
    Returns:
        bytes: The generated PDF as bytes
    
    Raises:
        RuntimeError: If ReportLab is not installed
    """
    if not REPORTLAB_AVAILABLE:
        raise RuntimeError("ReportLab is not installed. Install with: pip install reportlab")
    
    # Create PDF in memory
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, topMargin=0.75*inch, bottomMargin=0.75*inch)
    
    # Container for elements
    elements = []
    styles = getSampleStyleSheet()
    
    # Custom styles
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Title'],
        fontSize=24,
        textColor=colors.HexColor('#1976D2'),
        spaceAfter=20,
        alignment=1  # Center
    )
    
    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading1'],
        fontSize=16,
        textColor=colors.HexColor('#424242'),
        spaceAfter=12,
        spaceBefore=12
    )
    
    subheading_style = ParagraphStyle(
        'CustomSubHeading',
        parent=styles['Heading2'],
        fontSize=14,
        textColor=colors.HexColor('#616161'),
        spaceAfter=10,
        spaceBefore=10
    )
    
    body_style = ParagraphStyle(
        'CustomBody',
        parent=styles['BodyText'],
        fontSize=11,
        spaceAfter=6
    )
    
    # Title page
    elements.append(Paragraph(trip.destination, title_style))
    elements.append(Spacer(1, 0.2*inch))
    
    # Trip details
    trip_info = [
        ["Dates:", f"{trip.start_date.strftime('%B %d, %Y')} - {trip.end_date.strftime('%B %d, %Y')}"],
        ["Duration:", f"{(trip.end_date - trip.start_date).days + 1} days"],
        ["Budget:", f"${trip.budget_amount:,.2f}" if trip.budget_amount else "Not specified"],
    ]
    
    if trip.budget_tier:
        trip_info.append(["Budget Tier:", trip.budget_tier.value.title()])
    
    if trip.travel_style:
        trip_info.append(["Travel Style:", trip.travel_style.value.replace('_', ' ').title()])
    
    trip_table = Table(trip_info, colWidths=[1.5*inch, 4*inch])
    trip_table.setStyle(TableStyle([
        ('FONT', (0, 0), (-1, -1), 'Helvetica', 11),
        ('FONT', (0, 0), (0, -1), 'Helvetica-Bold', 11),
        ('TEXTCOLOR', (0, 0), (0, -1), colors.HexColor('#424242')),
        ('TEXTCOLOR', (1, 0), (1, -1), colors.HexColor('#616161')),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    
    elements.append(trip_table)
    elements.append(Spacer(1, 0.3*inch))
    
    # Itinerary section
    if days:
        elements.append(Paragraph("Itinerary", heading_style))
        elements.append(Spacer(1, 0.1*inch))
        
        # Sort days by date
        sorted_days = sorted(days, key=lambda d: d.date)
        
        for day in sorted_days:
            # Day header
            day_title = f"Day {day.day_number}: {day.date.strftime('%A, %B %d, %Y')}"
            elements.append(Paragraph(day_title, subheading_style))
            
            # Get activities for this day
            day_activities = [a for a in activities if a.day_id == day.id]
            day_activities.sort(key=lambda a: a.order_index)
            
            if day_activities:
                # Activities table
                activity_data = []
                for activity in day_activities:
                    time_str = activity.time.strftime('%I:%M %p') if activity.time else "—"
                    
                    name = activity.name
                    location = f"📍 {activity.location}" if activity.location else ""
                    description = activity.description or ""
                    
                    # Combine info
                    activity_info = name
                    if location:
                        activity_info += f"\n{location}"
                    if description:
                        activity_info += f"\n{description}"
                    
                    activity_data.append([time_str, activity_info])
                
                activity_table = Table(activity_data, colWidths=[1*inch, 4.5*inch])
                activity_table.setStyle(TableStyle([
                    ('FONT', (0, 0), (0, -1), 'Helvetica-Bold', 10),
                    ('FONT', (1, 0), (1, -1), 'Helvetica', 10),
                    ('TEXTCOLOR', (0, 0), (-1, -1), colors.HexColor('#616161')),
                    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ('LEFTPADDING', (0, 0), (-1, -1), 8),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                    ('TOPPADDING', (0, 0), (-1, -1), 6),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
                    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
                    ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F5F5F5')),
                ]))
                
                elements.append(activity_table)
            else:
                elements.append(Paragraph("No activities scheduled", body_style))
            
            elements.append(Spacer(1, 0.15*inch))
    
    # Budget breakdown section
    if budget_items:
        elements.append(PageBreak())
        elements.append(Paragraph("Budget Breakdown", heading_style))
        elements.append(Spacer(1, 0.1*inch))
        
        # Group budget items by category
        categories = {}
        for item in budget_items:
            cat = item.category.value if item.category else "other"
            if cat not in categories:
                categories[cat] = []
            categories[cat].append(item)
        
        # Budget table
        budget_data = [["Category", "Item", "Amount"]]
        total = 0.0
        
        for category, items in sorted(categories.items()):
            category_total = sum(item.amount for item in items)
            total += category_total
            
            for i, item in enumerate(items):
                if i == 0:
                    budget_data.append([
                        category.replace('_', ' ').title(),
                        item.description or "—",
                        f"${item.amount:,.2f}"
                    ])
                else:
                    budget_data.append([
                        "",
                        item.description or "—",
                        f"${item.amount:,.2f}"
                    ])
        
        # Add total row
        budget_data.append(["", "Total", f"${total:,.2f}"])
        
        budget_table = Table(budget_data, colWidths=[1.5*inch, 3*inch, 1.5*inch])
        budget_table.setStyle(TableStyle([
            ('FONT', (0, 0), (-1, 0), 'Helvetica-Bold', 11),
            ('FONT', (0, 1), (-1, -2), 'Helvetica', 10),
            ('FONT', (0, -1), (-1, -1), 'Helvetica-Bold', 11),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1976D2')),
            ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor('#E3F2FD')),
            ('ALIGN', (2, 0), (2, -1), 'RIGHT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ]))
        
        elements.append(budget_table)
        elements.append(Spacer(1, 0.2*inch))
    
    # Notes section
    if notes:
        elements.append(Paragraph("Notes", heading_style))
        elements.append(Spacer(1, 0.1*inch))
        
        for note in sorted(notes, key=lambda n: n.created_at):
            note_text = f"<b>{note.title or 'Note'}:</b> {note.content}"
            elements.append(Paragraph(note_text, body_style))
            elements.append(Spacer(1, 0.1*inch))
    
    # Footer
    elements.append(Spacer(1, 0.3*inch))
    footer_style = ParagraphStyle(
        'Footer',
        parent=styles['Normal'],
        fontSize=9,
        textColor=colors.grey,
        alignment=1  # Center
    )
    elements.append(Paragraph(f"Generated by TripCraft on {datetime.now().strftime('%B %d, %Y')}", footer_style))
    
    # Build PDF
    doc.build(elements)
    
    # Get PDF bytes
    buffer.seek(0)
    return buffer.read()


@router.post("/trips/{trip_id}/export", status_code=status.HTTP_200_OK)
async def export_trip(
    trip_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    Export a trip itinerary as a PDF.
    
    Generates a formatted PDF with the trip details, itinerary, budget breakdown,
    and notes. Uploads the PDF to Supabase Storage and returns a download URL.
    
    Args:
        trip_id: ID of the trip to export
        session: Database session
        current_user: Authenticated user
    
    Returns:
        dict: Contains the download URL and file information
        
    Raises:
        HTTPException 404: Trip not found
        HTTPException 403: User doesn't own the trip
        HTTPException 500: PDF generation or upload failed
        HTTPException 503: Required services unavailable
    """
    # Check if ReportLab is available
    if not REPORTLAB_AVAILABLE:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="PDF generation service unavailable. ReportLab not installed."
        )
    
    # Fetch trip
    trip = session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    # Check ownership
    if trip.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to export this trip"
        )
    
    # Fetch related data
    days = session.exec(
        select(Day).where(Day.trip_id == trip_id)
    ).all()
    
    activities = session.exec(
        select(Activity).where(Activity.day_id.in_([d.id for d in days]))
    ).all() if days else []
    
    budget_items = session.exec(
        select(BudgetItem).where(BudgetItem.trip_id == trip_id)
    ).all()
    
    notes = session.exec(
        select(Note).where(Note.trip_id == trip_id)
    ).all()
    
    # Generate PDF
    try:
        pdf_bytes = generate_trip_pdf(trip, list(days), list(activities), list(budget_items), list(notes))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate PDF: {str(e)}"
        )
    
    # Initialize Supabase client
    supabase = get_supabase_client()
    
    if not supabase:
        # Supabase not configured - return PDF as base64 for download
        import base64
        pdf_base64 = base64.b64encode(pdf_bytes).decode('utf-8')
        
        return {
            "success": True,
            "filename": f"trip_{trip_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf",
            "size_bytes": len(pdf_bytes),
            "download_url": None,
            "pdf_base64": pdf_base64,
            "message": "Supabase not configured. PDF returned as base64."
        }
    
    # Upload to Supabase Storage
    try:
        bucket_name = os.getenv("SUPABASE_BUCKET", "trip-exports")
        filename = f"trip_{trip_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
        file_path = f"{current_user.id}/{filename}"
        
        # Upload file
        response = supabase.storage.from_(bucket_name).upload(
            path=file_path,
            file=pdf_bytes,
            file_options={"content-type": "application/pdf"}
        )
        
        # Get public URL
        public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
        
        return {
            "success": True,
            "filename": filename,
            "size_bytes": len(pdf_bytes),
            "download_url": public_url,
            "storage_path": file_path
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload PDF to storage: {str(e)}"
        )
