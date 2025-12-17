import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity.dart';
import '../../models/day.dart';
import '../../models/trip.dart';
import '../../models/note.dart';
import '../../services/local_storage_service.dart';
import '../../providers/providers.dart';
import '../../utils/validators.dart';
import '../../utils/formatters.dart';

/// Activity Detail Screen - View and edit individual activity
/// 
/// Features:
/// - Display activity details (title, time, location, cost, details)
/// - Inline editing of all fields
/// - Time picker for start/end times
/// - Notes management (add, edit, delete)
/// - Save changes back to trip
/// - Delete activity confirmation
class ActivityDetailScreen extends ConsumerStatefulWidget {
  final String tripId;
  final int dayIndex;
  final String activityId;

  const ActivityDetailScreen({
    super.key,
    required this.tripId,
    required this.dayIndex,
    required this.activityId,
  });

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for editable fields
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _detailsController;
  late TextEditingController _costController;
  
  // Time values
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  
  // Notes
  List<Note> _notes = [];
  final TextEditingController _noteController = TextEditingController();
  
  // State
  bool _isEditing = false;
  bool _isSaving = false;
  Activity? _originalActivity;
  Trip? _trip;
  Day? _day;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _locationController = TextEditingController();
    _detailsController = TextEditingController();
    _costController = TextEditingController();
    _loadActivity();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    debugPrint('🔵 Loading activity - dayIndex: ${widget.dayIndex}, activityId: ${widget.activityId}');
    
    final storage = ref.read(localStorageServiceProvider);
    final trip = await storage.getTrip(widget.tripId);
    
    if (trip == null) {
      debugPrint('❌ Trip not found: ${widget.tripId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip not found')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    debugPrint('🔵 Trip loaded with ${trip.days.length} days');
    
    // Find day by dayIndex (not array index!)
    final day = trip.days.firstWhere(
      (d) => d.dayIndex == widget.dayIndex,
      orElse: () => Day(dayIndex: widget.dayIndex, activities: []),
    );
    
    if (day.activities.isEmpty) {
      debugPrint('❌ Day ${widget.dayIndex} has no activities or not found');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day not found')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    debugPrint('🔵 Day ${widget.dayIndex} found with ${day.activities.length} activities');
    
    final activity = day.activities.firstWhere(
      (a) => a.id == widget.activityId,
      orElse: () => Activity(title: ''),
    );
    
    if (activity.title.isEmpty) {
      debugPrint('❌ Activity ${widget.activityId} not found in day ${widget.dayIndex}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity not found')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    debugPrint('✅ Activity loaded: ${activity.title}');
    
    if (!mounted) return;
    
    setState(() {
      _trip = trip;
      _day = day;
      _originalActivity = activity;
      _titleController.text = activity.title;
      _locationController.text = activity.location ?? '';
      _detailsController.text = activity.details ?? '';
      _costController.text = activity.estimatedCost > 0 
          ? activity.estimatedCost.toStringAsFixed(2) 
          : '';
      
      // Parse time strings
      if (activity.startTime != null) {
        _startTime = _parseTime(activity.startTime!);
      }
      if (activity.endTime != null) {
        _endTime = _parseTime(activity.endTime!);
      }
      
      // Load notes from day (notes are stored at day level in spec)
      _notes = [...day.notes];
    });
    
    debugPrint('✅ Activity detail screen initialized');
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      // Invalid format
    }
    return null;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final initialTime = isStartTime ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    try {
      final storage = ref.read(localStorageServiceProvider);
      
      // Create updated activity
      final updatedActivity = _originalActivity!.copyWith(
        title: _titleController.text.trim(),
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        details: _detailsController.text.trim().isEmpty 
            ? null 
            : _detailsController.text.trim(),
        estimatedCost: _costController.text.isEmpty 
            ? 0.0 
            : double.tryParse(_costController.text) ?? 0.0,
        startTime: _startTime != null ? _formatTime(_startTime!) : null,
        endTime: _endTime != null ? _formatTime(_endTime!) : null,
      );

      // Update activity in day
      final updatedActivities = _day!.activities.map((a) {
        return a.id == widget.activityId ? updatedActivity : a;
      }).toList();

      final updatedDay = _day!.copyWith(
        activities: updatedActivities,
        notes: _notes, // Save updated notes
      );

      // Update day in trip
      final updatedDays = _trip!.days.map((d) {
        return d.dayIndex == widget.dayIndex ? updatedDay : d;
      }).toList();

      final updatedTrip = _trip!.copyWith(
        days: updatedDays,
        isSynced: false, // Mark for sync
        localUpdatedAt: DateTime.now(),
      );

      await storage.saveTrip(updatedTrip);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _originalActivity = updatedActivity;
          _trip = updatedTrip;
          _day = updatedDay;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving activity: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text(
          'Are you sure you want to delete this activity? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final storage = ref.read(localStorageServiceProvider);
      
      debugPrint('🗑️ Deleting activity: ${widget.activityId}');
      debugPrint('🗑️ Before delete - activities count: ${_day!.activities.length}');
      
      // Remove activity from day
      final updatedActivities = _day!.activities
          .where((a) => a.id != widget.activityId)
          .toList();

      debugPrint('🗑️ After delete - activities count: ${updatedActivities.length}');

      final updatedDay = _day!.copyWith(activities: updatedActivities);
      
      debugPrint('🗑️ Updated day activities: ${updatedDay.activities.length}');
      debugPrint('🗑️ Day index being updated: ${widget.dayIndex}');

      // Update day in trip
      final updatedDays = _trip!.days.map((d) {
        debugPrint('🗑️ Checking day ${d.dayIndex} against ${widget.dayIndex}');
        return d.dayIndex == widget.dayIndex ? updatedDay : d;
      }).toList();
      
      debugPrint('🗑️ Total activities across all days: ${updatedDays.fold(0, (sum, day) => sum + day.activities.length)}');

      final updatedTrip = _trip!.copyWith(
        days: updatedDays,
        isSynced: false,
        localUpdatedAt: DateTime.now(),
      );
      
      debugPrint('🗑️ Updated trip total activities: ${updatedTrip.days.fold(0, (sum, day) => sum + day.activities.length)}');

      await storage.saveTrip(updatedTrip);
      
      debugPrint('✅ Activity deleted and trip saved');
      
      // Invalidate the trip provider cache to force refresh
      ref.invalidate(tripProvider(widget.tripId));

      if (mounted) {
        context.pop(); // Go back to trip detail
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Activity deleted successfully')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting activity: $e')),
        );
      }
    }
  }

  void _addNote() {
    if (_noteController.text.trim().isEmpty) return;

    setState(() {
      _notes.add(Note(content: _noteController.text.trim()));
      _noteController.clear();
    });
  }

  void _deleteNote(String noteId) {
    setState(() {
      _notes.removeWhere((n) => n.id == noteId);
    });
  }

  void _editNote(Note note) {
    _noteController.text = note.content;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Note',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _noteController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                final index = _notes.indexWhere((n) => n.id == note.id);
                if (index != -1) {
                  _notes[index] = note.updateContent(_noteController.text.trim());
                }
                _noteController.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_originalActivity == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Activity Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Activity',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Reset to original values
                setState(() {
                  _isEditing = false;
                  _titleController.text = _originalActivity!.title;
                  _locationController.text = _originalActivity!.location ?? '';
                  _detailsController.text = _originalActivity!.details ?? '';
                  _costController.text = _originalActivity!.estimatedCost > 0
                      ? _originalActivity!.estimatedCost.toStringAsFixed(2)
                      : '';
                  if (_originalActivity!.startTime != null) {
                    _startTime = _parseTime(_originalActivity!.startTime!);
                  } else {
                    _startTime = null;
                  }
                  if (_originalActivity!.endTime != null) {
                    _endTime = _parseTime(_originalActivity!.endTime!);
                  } else {
                    _endTime = null;
                  }
                });
              },
              tooltip: 'Cancel',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteActivity();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Activity'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        key: const Key('activity_scroll_view'),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Activity Title',
                          prefixIcon: const Icon(Icons.title),
                          border: const OutlineInputBorder(),
                          enabled: _isEditing,
                        ),
                        validator: (value) => validateRequired(value, 'Activity Title'),
                        maxLength: 100,
                      ),
                      const SizedBox(height: 16),

                      // Time Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTimeField(
                                      context,
                                      label: 'Start Time',
                                      time: _startTime,
                                      onTap: _isEditing
                                          ? () => _selectTime(context, true)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTimeField(
                                      context,
                                      label: 'End Time',
                                      time: _endTime,
                                      onTap: _isEditing
                                          ? () => _selectTime(context, false)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          prefixIcon: const Icon(Icons.place),
                          border: const OutlineInputBorder(),
                          enabled: _isEditing,
                        ),
                        maxLength: 200,
                      ),
                      const SizedBox(height: 16),

                      // Details
                      TextFormField(
                        controller: _detailsController,
                        decoration: InputDecoration(
                          labelText: 'Details',
                          prefixIcon: const Icon(Icons.description),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          enabled: _isEditing,
                        ),
                        maxLines: 5,
                        maxLength: 500,
                      ),
                      const SizedBox(height: 16),

                      // Cost
                      TextFormField(
                        controller: _costController,
                        decoration: InputDecoration(
                          labelText: 'Estimated Cost',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: const OutlineInputBorder(),
                          enabled: _isEditing,
                          helperText: 'Optional',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return null;
                          final cost = double.tryParse(value);
                          if (cost == null || cost < 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Notes Section
                      Card(
                        key: const Key('notes_section'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.note,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Notes',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Add note field
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _noteController,
                                      decoration: const InputDecoration(
                                        hintText: 'Add a note...',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 2,
                                      onSubmitted: (_) => _addNote(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle),
                                    onPressed: _addNote,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Notes list
                              if (_notes.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'No notes yet. Add one above!',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _notes.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final note = _notes[index];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.note_outlined,
                                          size: 20,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      title: Text(note.content),
                                      subtitle: Text(
                                        'Updated ${formatDate(note.updatedAt)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            key: Key('edit_note_${note.id}'),
                                            icon: const Icon(Icons.edit, size: 20),
                                            onPressed: () => _editNote(note),
                                          ),
                                          IconButton(
                                            key: Key('delete_note_${note.id}'),
                                            icon: const Icon(Icons.delete, size: 20),
                                            color: theme.colorScheme.error,
                                            onPressed: () => _deleteNote(note.id),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save button (only visible when editing)
                      if (_isEditing)
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveActivity,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildTimeField(
    BuildContext context, {
    required String label,
    required TimeOfDay? time,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(
            Icons.access_time,
            color: enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          enabled: enabled,
        ),
        child: Text(
          time != null ? time.format(context) : 'Not set',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: time != null
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
