import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/validators.dart';
import '../../utils/formatters.dart';

class TripFormScreen extends ConsumerStatefulWidget {
  final String? tripId; // null for create, non-null for edit

  const TripFormScreen({
    super.key,
    this.tripId,
  });

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _titleController = TextEditingController();
  final _preferencesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _travelStyle;
  String? _budgetTier;
  bool _isLoading = false;
  Trip? _existingTrip;

  @override
  void initState() {
    super.initState();
    _loadTripIfEditing();
  }

  Future<void> _loadTripIfEditing() async {
    if (widget.tripId != null) {
      setState(() => _isLoading = true);
      try {
        final localStorage = ref.read(localStorageServiceProvider);
        final trip = await localStorage.getTrip(widget.tripId!);
        if (trip != null && mounted) {
          setState(() {
            _existingTrip = trip;
            _destinationController.text = trip.destination;
            _titleController.text = trip.title ?? '';
            _preferencesController.text = trip.preferences ?? '';
            _startDate = trip.startDate;
            _endDate = trip.endDate;
            _travelStyle = trip.travelStyle;
            _budgetTier = trip.budgetTier;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading trip: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _titleController.dispose();
    _preferencesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start date first'),
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 7)),
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: maxTripDays)),
    );

    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }

  int? get _tripDuration {
    if (_startDate == null || _endDate == null) return null;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  String? _validateDates() {
    if (_startDate == null) {
      return 'Start date is required';
    }
    if (_endDate == null) {
      return 'End date is required';
    }
    final duration = _tripDuration;
    if (duration != null) {
      if (duration < minTripDays) {
        return 'Trip must be at least $minTripDays day';
      }
      if (duration > maxTripDays) {
        return 'Trip cannot exceed $maxTripDays days';
      }
    }
    return null;
  }

  Future<void> _saveTrip() async {
    // Clear any previous errors
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate dates
    final dateError = _validateDates();
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dateError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final localStorage = ref.read(localStorageServiceProvider);
      final authState = ref.read(authStateProvider);
      final userId = authState.user?.id ?? 'unknown';

      // Generate days for new trips
      List<Day> tripDays = _existingTrip?.days ?? [];
      if (_existingTrip == null && _startDate != null && _endDate != null) {
        // Create empty days for new trip
        final duration = _endDate!.difference(_startDate!).inDays + 1;
        tripDays = List.generate(duration, (index) {
          return Day(
            dayIndex: index + 1,
            date: _startDate!.add(Duration(days: index)),
            activities: [],
            summary: 'Day ${index + 1}',
          );
        });
      }

      final trip = Trip(
        id: _existingTrip?.id,
        userId: userId,
        serverId: _existingTrip?.serverId,
        destination: _destinationController.text.trim(),
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        travelStyle: _travelStyle,
        budgetTier: _budgetTier,
        preferences: _preferencesController.text.trim().isEmpty
            ? null
            : _preferencesController.text.trim(),
        days: tripDays,
        notes: _existingTrip?.notes ?? [],
        budgetItems: _existingTrip?.budgetItems ?? [],
        totalBudgetEstimate: _existingTrip?.totalBudgetEstimate ?? 0.0,
        localTips: _existingTrip?.localTips ?? [],
        isSynced: false, // Mark as unsynced after edit
        createdAt: _existingTrip?.createdAt,
      );

      if (_existingTrip != null) {
        // Update existing trip
        await localStorage.saveTrip(trip);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Trip updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new trip
        await localStorage.saveTrip(trip);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Trip created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        // Navigate back to home
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
          'Are you sure you want to delete this trip? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteTrip();
    }
  }

  Future<void> _deleteTrip() async {
    if (_existingTrip == null) return;

    setState(() => _isLoading = true);

    try {
      final localStorage = ref.read(localStorageServiceProvider);
      await localStorage.deleteTrip(_existingTrip!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Trip deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _generateWithAI() {
    // Validate required fields for AI generation
    final dateError = _validateDates();
    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a destination first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dateError),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to generation screen
    context.go(
      '/generate',
      extra: {
        'destination': _destinationController.text.trim(),
        'startDate': _startDate!,
        'endDate': _endDate!,
        'travelStyle': _travelStyle,
        'budgetTier': _budgetTier,
        'preferences': _preferencesController.text.trim().isEmpty
            ? null
            : _preferencesController.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = _existingTrip != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
          tooltip: 'Back to home',
        ),
        title: Text(isEditing ? 'Edit Trip' : 'Create Trip'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : _confirmDelete,
              tooltip: 'Delete trip',
            ),
        ],
      ),
      body: _isLoading && _existingTrip == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.travel_explore,
                                color: theme.colorScheme.primary,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isEditing
                                      ? 'Update your trip details'
                                      : 'Plan your next adventure',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fill in the basic information about your trip',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Destination (Required)
                  Text(
                    'Destination *',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Paris, France',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: validateDestination,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Trip Title (Optional)
                  Text(
                    'Trip Title (Optional)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Summer Vacation 2025',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Dates Section
                  Text(
                    'Travel Dates *',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _selectStartDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _startDate == null
                                ? 'Start Date'
                                : formatDate(_startDate!),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _selectEndDate,
                          icon: const Icon(Icons.event),
                          label: Text(
                            _endDate == null
                                ? 'End Date'
                                : formatDate(_endDate!),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_tripDuration != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 20,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Duration: ${formatDuration(_tripDuration!)}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Travel Style
                  Text(
                    'Travel Style',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: travelStyles.map((style) {
                      final isSelected = _travelStyle == style;
                      return FilterChip(
                        label: Text(
                          style[0].toUpperCase() + style.substring(1),
                        ),
                        selected: isSelected,
                        onSelected: _isLoading
                            ? null
                            : (selected) {
                                setState(() {
                                  _travelStyle = selected ? style : null;
                                });
                              },
                        showCheckmark: true,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Budget Tier
                  Text(
                    'Budget Tier',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: budgetTiers.map((tier) {
                      final isSelected = _budgetTier == tier;
                      return FilterChip(
                        label: Text(
                          tier[0].toUpperCase() + tier.substring(1),
                        ),
                        selected: isSelected,
                        onSelected: _isLoading
                            ? null
                            : (selected) {
                                setState(() {
                                  _budgetTier = selected ? tier : null;
                                });
                              },
                        showCheckmark: true,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Preferences (Optional)
                  Text(
                    'Preferences (Optional)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _preferencesController,
                    decoration: InputDecoration(
                      hintText:
                          'e.g., Vegetarian food, avoid crowds, love museums...',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _saveTrip,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(isEditing ? Icons.save : Icons.check),
                    label: Text(
                      isEditing ? 'Update Trip' : 'Create Trip',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Generate with AI Button (only for create mode)
                  if (!isEditing) ...[
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _generateWithAI,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate with AI'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Cancel Button
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
