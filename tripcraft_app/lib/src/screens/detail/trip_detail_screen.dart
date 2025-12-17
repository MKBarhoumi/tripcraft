import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/formatters.dart';

/// Screen for displaying detailed trip information with day-by-day itinerary
/// Supports viewing all trip details, editing activities inline, and managing the trip
class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  int _selectedDayIndex = 0;
  int _refreshCounter = 0;

  void _refresh() {
    setState(() {
      _refreshCounter++;
    });
    debugPrint('🔄 Refreshing trip detail screen (counter: $_refreshCounter)');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localStorage = ref.watch(localStorageServiceProvider);

    return FutureBuilder<Trip?>(
      key: ValueKey(_refreshCounter), // Forces rebuild when counter changes
      future: localStorage.getTrip(widget.tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading...'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final trip = snapshot.data;
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Trip Not Found'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trip not found',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This trip may have been deleted',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.home),
                    label: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/home'),
              tooltip: 'Back to home',
            ),
            title: Text(
              trip.destination,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Trip',
                onPressed: () {
                  context.push('/trip/${trip.id}/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet),
                tooltip: 'Budget Tracker',
                onPressed: () {
                  context.push('/trip/${trip.id}/budget');
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleMenuAction(value, trip),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Trip', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf),
                        SizedBox(width: 8),
                        Text('Export PDF'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Trip Header
              SliverToBoxAdapter(
                child: _buildTripHeader(trip, theme),
              ),

              // Day Tabs
              if (trip.days.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildDayTabs(trip, theme),
                ),

              // Selected Day Content
              if (trip.days.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildDayContent(trip, trip.days[_selectedDayIndex], theme),
                )
              else
                SliverFillRemaining(
                  child: _buildEmptyState(theme),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              // Refresh trip data
              final localStorage = ref.read(localStorageServiceProvider);
              final currentTrip = await localStorage.getTrip(widget.tripId);
              
              if (currentTrip == null) return;
              
              // Auto-generate days if they don't exist
              if (currentTrip.days.isEmpty && currentTrip.startDate != null && currentTrip.endDate != null) {
                final duration = currentTrip.endDate!.difference(currentTrip.startDate!).inDays + 1;
                final newDays = List.generate(duration, (index) {
                  return Day(
                    dayIndex: index + 1,
                    date: currentTrip.startDate!.add(Duration(days: index)),
                    activities: [],
                    summary: 'Day ${index + 1}',
                  );
                });
                
                final updatedTrip = currentTrip.copyWith(days: newDays);
                await localStorage.saveTrip(updatedTrip);
              }
              
              // Fetch updated trip and show dialog
              final refreshedTrip = await localStorage.getTrip(widget.tripId);
              if (mounted && refreshedTrip != null) {
                _showAddActivityDialog(context, refreshedTrip);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Activity'),
          ),
        );
      },
    );
  }

  Widget _buildTripHeader(Trip trip, ThemeData theme) {
    final startDate = trip.startDate ?? DateTime.now();
    final endDate = trip.endDate ?? DateTime.now();
    final duration = endDate.difference(startDate).inDays + 1;
    final totalBudget = _calculateTotalBudget(trip);
    final totalActivities = trip.days.fold<int>(
      0,
      (sum, day) => sum + day.activities.length,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destination
          Row(
            children: [
              Icon(
                Icons.place,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trip.destination,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Trip Stats Row
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildStatChip(
                icon: Icons.calendar_today,
                label: formatDateRange(startDate, endDate),
                theme: theme,
              ),
              _buildStatChip(
                icon: Icons.access_time,
                label: formatDuration(duration),
                theme: theme,
              ),
              _buildStatChip(
                icon: Icons.location_on,
                label: '$totalActivities activities',
                theme: theme,
              ),
              if (totalBudget > 0)
                _buildStatChip(
                  icon: Icons.attach_money,
                  label: '\$${totalBudget.toStringAsFixed(0)}',
                  theme: theme,
                ),
            ],
          ),

          // Travel Style & Budget Tier
          if (trip.travelStyle != null || trip.budgetTier != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (trip.travelStyle != null)
                  Chip(
                    label: Text(
                      trip.travelStyle![0].toUpperCase() +
                          trip.travelStyle!.substring(1),
                    ),
                    avatar: const Icon(Icons.style, size: 18),
                  ),
                if (trip.budgetTier != null)
                  Chip(
                    label: Text(
                      trip.budgetTier![0].toUpperCase() +
                          trip.budgetTier!.substring(1),
                    ),
                    avatar: const Icon(Icons.payments, size: 18),
                  ),
              ],
            ),
          ],

          // Preferences
          if (trip.preferences != null && trip.preferences!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.preferences!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabs(Trip trip, ThemeData theme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: trip.days.length,
        itemBuilder: (context, index) {
          final day = trip.days[index];
          final isSelected = index == _selectedDayIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Day ${day.dayIndex}'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedDayIndex = index);
                }
              },
              avatar: isSelected
                  ? Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayContent(Trip trip, Day day, ThemeData theme) {
    final date = (trip.startDate != null)
        ? trip.startDate!.add(Duration(days: day.dayIndex - 1))
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.today,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${day.dayIndex}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (date != null)
                      Text(
                        formatDate(date),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${day.activities.length} activities',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Activities List
          if (day.activities.isEmpty)
            _buildEmptyDayState(theme)
          else
            ...day.activities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              final isLast = index == day.activities.length - 1;

              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: _buildActivityCard(activity, day, theme),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Activity activity, Day day, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          try {
            debugPrint('🔵 Tapping activity: ${activity.id}');
            debugPrint('🔵 Day dayIndex: ${day.dayIndex}');
            debugPrint('🔵 Trip ID: ${widget.tripId}');
            final path = '/trip/${widget.tripId}/day/${day.dayIndex}/activity/${activity.id}';
            debugPrint('🔵 Navigating to: $path');
            
            await context.push(path);
            debugPrint('🔵 Returned from activity detail');
            
            // Refresh the screen when returning from activity detail
            _refresh();
          } catch (e, stackTrace) {
            debugPrint('❌ Error navigating to activity: $e');
            debugPrint('Stack trace: $stackTrace');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Activity Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.place,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Activity Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (activity.location != null)
                          Text(
                            activity.location!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Time
                  if (activity.startTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity.startTime!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),

              // Description
              if (activity.details != null && activity.details!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  activity.details!,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Footer with cost
              if (activity.estimatedCost > 0) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '\$${activity.estimatedCost.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDayState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No activities planned for this day',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first activity',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No itinerary yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This trip doesn\'t have any days or activities planned yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                context.push('/trip/${widget.tripId}/edit');
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Trip'),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalBudget(Trip trip) {
    double total = 0.0;
    for (final day in trip.days) {
      for (final activity in day.activities) {
        total += activity.estimatedCost;
      }
    }
    return total;
  }

  Future<void> _handleMenuAction(String action, Trip trip) async {
    switch (action) {
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Trip?'),
            content: Text(
              'Are you sure you want to delete "${trip.destination}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true && mounted) {
          final localStorage = ref.read(localStorageServiceProvider);
          await localStorage.deleteTrip(trip.id);
          if (mounted) {
            context.go('/home');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trip deleted')),
            );
          }
        }
        break;

      case 'export':
        // TODO: Implement PDF export in future task
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF export coming soon!'),
            ),
          );
        }
        break;
    }
  }

  Future<void> _showAddActivityDialog(BuildContext context, Trip trip) async {
    if (trip.days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No days available. Edit trip to add dates.')),
      );
      return;
    }

    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final detailsController = TextEditingController();
    final costController = TextEditingController(text: '0');
    int selectedDayIndex = _selectedDayIndex;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add Activity'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Activity Title *',
                      hintText: 'e.g., Visit Eiffel Tower',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedDayIndex,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: trip.days.asMap().entries.map((entry) {
                      final day = entry.value;
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text('Day ${day.dayIndex}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedDayIndex = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(startTime.format(context)),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (picked != null) {
                              setState(() => startTime = picked);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time'),
                          subtitle: Text(endTime.format(context)),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (picked != null) {
                              setState(() => endTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'e.g., Paris, France',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: detailsController,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      hintText: 'Add notes or description',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: costController,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Cost',
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a title')),
                    );
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );

      if (result == true && mounted) {
        final newActivity = Activity(
          title: titleController.text.trim(),
          startTime: '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
          endTime: '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
          location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
          details: detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
          estimatedCost: double.tryParse(costController.text) ?? 0.0,
        );

        final updatedDay = trip.days[selectedDayIndex].copyWith(
          activities: [...trip.days[selectedDayIndex].activities, newActivity],
        );

        final updatedDays = List<Day>.from(trip.days);
        updatedDays[selectedDayIndex] = updatedDay;

        final updatedTrip = trip.copyWith(days: updatedDays);

        final localStorage = ref.read(localStorageServiceProvider);
        await localStorage.saveTrip(updatedTrip);

        if (mounted) {
          setState(() {
            _selectedDayIndex = selectedDayIndex;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Activity added')),
          );
        }
      }
    } finally {
      // Wait for dialog animation to complete before disposing controllers
      await Future.delayed(const Duration(milliseconds: 100));
      titleController.dispose();
      locationController.dispose();
      detailsController.dispose();
      costController.dispose();
    }
  }
}
