# app/services/ai_service.py
# AI itinerary generation service using Groq

from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
from groq import Groq
import json

from ..core.config import settings


class AIService:
    """Service for AI-powered itinerary generation using Groq."""
    
    def __init__(self):
        self.client = Groq(api_key=settings.GROQ_API_KEY)
        self.model = settings.GROQ_MODEL
    
    def _calculate_days(self, start_date: str, end_date: str) -> int:
        """Calculate number of days between dates."""
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
        return (end - start).days + 1
    
    def _build_prompt(
        self,
        destination: str,
        start_date: str,
        end_date: str,
        budget: Optional[float] = None,
        budget_tier: Optional[str] = None,
        travel_style: Optional[str] = None,
        interests: Optional[List[str]] = None,
        special_requirements: Optional[str] = None
    ) -> str:
        """Build a detailed prompt for itinerary generation."""
        num_days = self._calculate_days(start_date, end_date)
        
        prompt = f"""Generate a detailed travel itinerary for a {num_days}-day trip to {destination}.

Trip Details:
- Destination: {destination}
- Duration: {num_days} days (from {start_date} to {end_date})
"""
        
        if budget:
            prompt += f"- Budget: ${budget:.2f}\n"
        
        if budget_tier:
            prompt += f"- Budget Tier: {budget_tier}\n"
        
        if travel_style:
            prompt += f"- Travel Style: {travel_style}\n"
        
        if interests:
            prompt += f"- Interests: {', '.join(interests)}\n"
        
        if special_requirements:
            prompt += f"- Special Requirements: {special_requirements}\n"
        
        prompt += f"""
Please create a comprehensive day-by-day itinerary in the following JSON format:

{{
  "days": [
    {{
      "day_number": 1,
      "date": "{start_date}",
      "title": "Day 1: Arrival and Exploration",
      "activities": [
        {{
          "time": "09:00 AM",
          "title": "Activity Title",
          "description": "Detailed description of the activity",
          "location": "Specific location name",
          "estimated_cost": 25.00,
          "notes": "Any helpful tips or notes"
        }}
      ]
    }}
  ]
}}

Requirements:
1. Create exactly {num_days} days
2. Each day should have 4-6 activities
3. Include realistic time slots (e.g., "09:00 AM", "02:30 PM")
4. Provide specific locations and descriptions
5. Include estimated costs in USD for each activity
6. Consider the budget tier: {budget_tier or 'moderate'}
7. Match the travel style: {travel_style or 'balanced'}
8. Incorporate interests: {', '.join(interests) if interests else 'general tourism'}
9. Account for special requirements: {special_requirements or 'none'}
10. Include a mix of activities: meals, attractions, rest periods, transportation
11. Make the itinerary realistic and practical
12. Ensure activities flow naturally throughout each day

Return ONLY the JSON object, no additional text or formatting.
"""
        return prompt
    
    def _parse_groq_response(self, response_text: str) -> Dict[str, Any]:
        """Parse Groq API response and extract JSON."""
        try:
            # Try to find JSON in the response
            start_idx = response_text.find('{')
            end_idx = response_text.rfind('}') + 1
            
            if start_idx == -1 or end_idx == 0:
                raise ValueError("No JSON found in response")
            
            json_str = response_text[start_idx:end_idx]
            return json.loads(json_str)
        
        except json.JSONDecodeError as e:
            raise ValueError(f"Failed to parse JSON from response: {e}")
    
    def _validate_itinerary(self, data: Dict[str, Any], num_days: int) -> None:
        """Validate the generated itinerary structure."""
        if "days" not in data:
            raise ValueError("Missing 'days' in itinerary")
        
        if not isinstance(data["days"], list):
            raise ValueError("'days' must be a list")
        
        if len(data["days"]) == 0:
            raise ValueError("Itinerary must have at least one day")
        
        for idx, day in enumerate(data["days"]):
            if not isinstance(day, dict):
                raise ValueError(f"Day {idx + 1} must be a dictionary")
            
            required_fields = ["day_number", "date", "activities"]
            for field in required_fields:
                if field not in day:
                    raise ValueError(f"Day {idx + 1} missing required field: {field}")
            
            if not isinstance(day["activities"], list):
                raise ValueError(f"Day {idx + 1} activities must be a list")
            
            for act_idx, activity in enumerate(day["activities"]):
                if not isinstance(activity, dict):
                    raise ValueError(f"Day {idx + 1}, activity {act_idx + 1} must be a dictionary")
                
                activity_fields = ["time", "title", "description"]
                for field in activity_fields:
                    if field not in activity:
                        raise ValueError(f"Day {idx + 1}, activity {act_idx + 1} missing: {field}")
    
    def generate_itinerary(
        self,
        destination: str,
        start_date: str,
        end_date: str,
        budget: Optional[float] = None,
        budget_tier: Optional[str] = None,
        travel_style: Optional[str] = None,
        interests: Optional[List[str]] = None,
        special_requirements: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Generate a complete travel itinerary using Groq AI.
        
        Args:
            destination: Travel destination
            start_date: Trip start date (YYYY-MM-DD)
            end_date: Trip end date (YYYY-MM-DD)
            budget: Total budget in USD
            budget_tier: Budget category (budget/moderate/luxury)
            travel_style: Travel style (relaxation/adventure/cultural/foodie)
            interests: List of interests
            special_requirements: Any special requirements
        
        Returns:
            Dictionary containing days and activities
        
        Raises:
            ValueError: If generation fails or response is invalid
        """
        num_days = self._calculate_days(start_date, end_date)
        
        if num_days < 1 or num_days > 14:
            raise ValueError("Trip duration must be between 1 and 14 days")
        
        # Build prompt
        prompt = self._build_prompt(
            destination=destination,
            start_date=start_date,
            end_date=end_date,
            budget=budget,
            budget_tier=budget_tier,
            travel_style=travel_style,
            interests=interests,
            special_requirements=special_requirements
        )
        
        try:
            # Call Groq API
            chat_completion = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert travel planner. Generate detailed, practical, and personalized travel itineraries in JSON format. Be specific with locations, times, and costs."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                model=self.model,
                temperature=0.7,
                max_tokens=4096,
                top_p=0.9
            )
            
            # Extract response
            response_text = chat_completion.choices[0].message.content
            
            # Parse JSON
            itinerary_data = self._parse_groq_response(response_text)
            
            # Validate structure
            self._validate_itinerary(itinerary_data, num_days)
            
            return itinerary_data
        
        except Exception as e:
            raise ValueError(f"Failed to generate itinerary: {str(e)}")
    
    def refine_itinerary(
        self,
        current_itinerary: Dict[str, Any],
        refinement_request: str,
        trip_context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Refine an existing itinerary based on user feedback.
        
        Args:
            current_itinerary: Current itinerary data
            refinement_request: User's refinement request
            trip_context: Trip context (destination, dates, preferences)
        
        Returns:
            Refined itinerary data
        """
        prompt = f"""Current itinerary for {trip_context.get('destination')}:

{json.dumps(current_itinerary, indent=2)}

User's refinement request:
"{refinement_request}"

Trip context:
- Destination: {trip_context.get('destination')}
- Duration: {trip_context.get('num_days')} days
- Budget: ${trip_context.get('budget', 'N/A')}
- Travel style: {trip_context.get('travel_style', 'balanced')}

Please modify the itinerary according to the user's request while maintaining the same JSON structure. Make specific changes requested but keep the overall itinerary coherent and practical.

Return ONLY the updated JSON object, no additional text.
"""
        
        try:
            chat_completion = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert travel planner. Refine travel itineraries based on user feedback while maintaining practicality and structure."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                model=self.model,
                temperature=0.7,
                max_tokens=4096
            )
            
            response_text = chat_completion.choices[0].message.content
            refined_data = self._parse_groq_response(response_text)
            self._validate_itinerary(refined_data, trip_context.get('num_days', 1))
            
            return refined_data
        
        except Exception as e:
            raise ValueError(f"Failed to refine itinerary: {str(e)}")
