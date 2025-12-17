// sample_trips.dart
// Utility to generate sample trips for new users

import '../models/models.dart';

/// Generate 5 random sample trips for demonstration
List<Trip> generateSampleTrips(String userId) {
  final now = DateTime.now();
  
  return [
    // Trip 1: Paris
    Trip(
      destination: 'Paris, France',
      title: 'Romantic Paris Getaway',
      startDate: now.add(const Duration(days: 30)),
      endDate: now.add(const Duration(days: 35)),
      userId: userId,
      budgetTier: 'mid',
      travelStyle: 'relaxed',
      days: [
        Day(
          dayIndex: 1,
          date: now.add(const Duration(days: 30)),
          summary: 'Arrival & Eiffel Tower',
          activities: [
            Activity(
              title: 'Visit Eiffel Tower',
              startTime: '10:00',
              endTime: '12:30',
              location: 'Eiffel Tower, Champ de Mars',
              details: 'Book tickets in advance to skip the line',
              estimatedCost: 25.0,
            ),
            Activity(
              title: 'Lunch at Café de l\'Homme',
              startTime: '13:00',
              endTime: '14:30',
              location: 'Place du Trocadéro',
              estimatedCost: 45.0,
            ),
            Activity(
              title: 'Seine River Cruise',
              startTime: '16:00',
              endTime: '17:30',
              location: 'Port de la Bourdonnais',
              details: 'Enjoy panoramic views of Paris landmarks',
              estimatedCost: 15.0,
            ),
          ],
        ),
        Day(
          dayIndex: 2,
          date: now.add(const Duration(days: 31)),
          summary: 'Louvre & Latin Quarter',
          activities: [
            Activity(
              title: 'Louvre Museum',
              startTime: '09:00',
              endTime: '13:00',
              location: 'Musée du Louvre',
              details: 'See the Mona Lisa and other masterpieces',
              estimatedCost: 17.0,
            ),
            Activity(
              title: 'Walk through Latin Quarter',
              startTime: '15:00',
              endTime: '18:00',
              location: 'Quartier Latin',
              estimatedCost: 0.0,
            ),
          ],
        ),
        Day(
          dayIndex: 3,
          date: now.add(const Duration(days: 32)),
          summary: 'Versailles Day Trip',
          activities: [
            Activity(
              title: 'Palace of Versailles',
              startTime: '09:00',
              endTime: '16:00',
              location: 'Versailles',
              details: 'Explore the palace and gardens',
              estimatedCost: 27.0,
            ),
          ],
        ),
      ],
    ),
    
    // Trip 2: Tokyo
    Trip(
      destination: 'Tokyo, Japan',
      title: 'Tokyo Adventure',
      startDate: now.add(const Duration(days: 60)),
      endDate: now.add(const Duration(days: 67)),
      userId: userId,
      budgetTier: 'mid',
      travelStyle: 'moderate',
      days: [
        Day(
          dayIndex: 1,
          date: now.add(const Duration(days: 60)),
          summary: 'Shibuya & Harajuku',
          activities: [
            Activity(
              title: 'Shibuya Crossing',
              startTime: '10:00',
              endTime: '11:00',
              location: 'Shibuya',
              estimatedCost: 0.0,
            ),
            Activity(
              title: 'Meiji Shrine',
              startTime: '11:30',
              endTime: '13:00',
              location: 'Harajuku',
              estimatedCost: 0.0,
            ),
            Activity(
              title: 'Takeshita Street Shopping',
              startTime: '14:00',
              endTime: '16:00',
              location: 'Harajuku',
              estimatedCost: 50.0,
            ),
          ],
        ),
        Day(
          dayIndex: 2,
          date: now.add(const Duration(days: 61)),
          summary: 'Asakusa & Tokyo Skytree',
          activities: [
            Activity(
              title: 'Senso-ji Temple',
              startTime: '09:00',
              endTime: '11:00',
              location: 'Asakusa',
              estimatedCost: 0.0,
            ),
            Activity(
              title: 'Tokyo Skytree',
              startTime: '14:00',
              endTime: '16:00',
              location: 'Sumida',
              estimatedCost: 28.0,
            ),
          ],
        ),
      ],
    ),
    
    // Trip 3: New York
    Trip(
      destination: 'New York, USA',
      title: 'Big Apple Experience',
      startDate: now.add(const Duration(days: 90)),
      endDate: now.add(const Duration(days: 94)),
      userId: userId,
      budgetTier: 'luxury',
      travelStyle: 'packed',
      days: [
        Day(
          dayIndex: 1,
          date: now.add(const Duration(days: 90)),
          summary: 'Manhattan Highlights',
          activities: [
            Activity(
              title: 'Central Park Walk',
              startTime: '09:00',
              endTime: '11:00',
              location: 'Central Park',
              estimatedCost: 0.0,
            ),
            Activity(
              title: 'Metropolitan Museum of Art',
              startTime: '12:00',
              endTime: '15:00',
              location: 'The Met',
              estimatedCost: 30.0,
            ),
            Activity(
              title: 'Times Square at Night',
              startTime: '19:00',
              endTime: '21:00',
              location: 'Times Square',
              estimatedCost: 0.0,
            ),
          ],
        ),
        Day(
          dayIndex: 2,
          date: now.add(const Duration(days: 91)),
          summary: 'Statue of Liberty & Brooklyn',
          activities: [
            Activity(
              title: 'Statue of Liberty & Ellis Island',
              startTime: '09:00',
              endTime: '14:00',
              location: 'Liberty Island',
              estimatedCost: 24.0,
            ),
            Activity(
              title: 'Brooklyn Bridge Walk',
              startTime: '16:00',
              endTime: '17:30',
              location: 'Brooklyn Bridge',
              estimatedCost: 0.0,
            ),
          ],
        ),
      ],
    ),
    
    // Trip 4: Bali
    Trip(
      destination: 'Bali, Indonesia',
      title: 'Tropical Paradise',
      startDate: now.add(const Duration(days: 120)),
      endDate: now.add(const Duration(days: 129)),
      userId: userId,
      budgetTier: 'budget',
      travelStyle: 'relaxed',
      days: [
        Day(
          dayIndex: 1,
          date: now.add(const Duration(days: 120)),
          summary: 'Ubud Culture',
          activities: [
            Activity(
              title: 'Tegalalang Rice Terraces',
              startTime: '08:00',
              endTime: '10:00',
              location: 'Ubud',
              estimatedCost: 5.0,
            ),
            Activity(
              title: 'Ubud Monkey Forest',
              startTime: '11:00',
              endTime: '13:00',
              location: 'Ubud',
              estimatedCost: 7.0,
            ),
            Activity(
              title: 'Balinese Spa Treatment',
              startTime: '16:00',
              endTime: '18:00',
              location: 'Ubud',
              estimatedCost: 25.0,
            ),
          ],
        ),
        Day(
          dayIndex: 2,
          date: now.add(const Duration(days: 121)),
          summary: 'Beach Day',
          activities: [
            Activity(
              title: 'Seminyak Beach',
              startTime: '10:00',
              endTime: '17:00',
              location: 'Seminyak',
              details: 'Relax on the beach and enjoy water sports',
              estimatedCost: 20.0,
            ),
            Activity(
              title: 'Sunset at Tanah Lot Temple',
              startTime: '18:00',
              endTime: '19:30',
              location: 'Tanah Lot',
              estimatedCost: 8.0,
            ),
          ],
        ),
      ],
    ),
    
    // Trip 5: Barcelona
    Trip(
      destination: 'Barcelona, Spain',
      title: 'Gaudi & Tapas Tour',
      startDate: now.add(const Duration(days: 150)),
      endDate: now.add(const Duration(days: 155)),
      userId: userId,
      budgetTier: 'mid',
      travelStyle: 'moderate',
      days: [
        Day(
          dayIndex: 1,
          date: now.add(const Duration(days: 150)),
          summary: 'Gaudi Masterpieces',
          activities: [
            Activity(
              title: 'Sagrada Familia',
              startTime: '09:00',
              endTime: '11:30',
              location: 'Eixample',
              details: 'Book tickets online in advance',
              estimatedCost: 26.0,
            ),
            Activity(
              title: 'Park Güell',
              startTime: '14:00',
              endTime: '16:00',
              location: 'Gràcia',
              estimatedCost: 10.0,
            ),
            Activity(
              title: 'Tapas Dinner in Gothic Quarter',
              startTime: '20:00',
              endTime: '22:00',
              location: 'Barri Gòtic',
              estimatedCost: 35.0,
            ),
          ],
        ),
        Day(
          dayIndex: 2,
          date: now.add(const Duration(days: 151)),
          summary: 'Beach & Las Ramblas',
          activities: [
            Activity(
              title: 'Barceloneta Beach',
              startTime: '10:00',
              endTime: '14:00',
              location: 'Barceloneta',
              estimatedCost: 0.0,
            ),
            Activity(
              title: 'Walk Las Ramblas',
              startTime: '16:00',
              endTime: '18:00',
              location: 'Las Ramblas',
              details: 'Visit La Boqueria Market',
              estimatedCost: 15.0,
            ),
          ],
        ),
      ],
    ),
  ];
}
