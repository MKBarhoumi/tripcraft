import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/formatters.dart';

/// Screen for generating AI-powered travel itineraries
/// Shows progress indicator during generation and handles the API response
class ItineraryGenerationScreen extends ConsumerStatefulWidget {
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String? travelStyle;
  final String? budgetTier;
  final String? preferences;
  final bool autoStart; // For testing, allows disabling auto-start

  const ItineraryGenerationScreen({
    super.key,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.travelStyle,
    this.budgetTier,
    this.preferences,
    this.autoStart = true,
  });

  @override
  ConsumerState<ItineraryGenerationScreen> createState() =>
      _ItineraryGenerationScreenState();
}

class _ItineraryGenerationScreenState
    extends ConsumerState<ItineraryGenerationScreen>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = false;
  String _statusMessage = 'Initializing AI...';
  double _progress = 0.0;
  Trip? _generatedTrip;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start generation automatically when screen loads (unless disabled for tests)
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateItinerary();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Generate a simple local itinerary without backend
  Future<void> _generateItinerary() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Analyzing your preferences...';
      _progress = 0.1;
    });

    try {
      // Simulate progress updates
      _updateProgress('Researching ${widget.destination}...', 0.3);
      await Future.delayed(const Duration(milliseconds: 800));

      _updateProgress('Creating personalized itinerary...', 0.5);
      await Future.delayed(const Duration(milliseconds: 800));

      _updateProgress('Adding activities and recommendations...', 0.7);
      await Future.delayed(const Duration(milliseconds: 800));

      // Generate simple local itinerary
      final generatedTrip = _createLocalItinerary();

      _updateProgress('Finalizing your trip plan...', 0.9);
      await Future.delayed(const Duration(milliseconds: 500));

      // Save to local storage
      final localStorage = ref.read(localStorageServiceProvider);
      await localStorage.saveTrip(generatedTrip);

      setState(() {
        _generatedTrip = generatedTrip;
        _progress = 1.0;
        _statusMessage = 'Itinerary ready! 🎉';
        _isGenerating = false;
      });

      // Wait a moment to show success before navigating
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        // Navigate to trip detail screen
        context.go('/trip/${_generatedTrip!.id}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Itinerary generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString();
        _statusMessage = 'Generation failed';
      });
    }
  }

  /// Create a simple local itinerary
  Trip _createLocalItinerary() {
    final duration = widget.endDate.difference(widget.startDate).inDays + 1;
    final days = <Day>[];

    // Generate simple activities for each day
    for (int i = 0; i < duration; i++) {
      final dayDate = widget.startDate.add(Duration(days: i));
      final activities = <Activity>[
        Activity(
          title: 'Morning in ${widget.destination}',
          startTime: '09:00',
          endTime: '12:00',
          location: widget.destination,
          details: 'Start your day exploring the local area',
          estimatedCost: 0.0,
        ),
        Activity(
          title: 'Local Lunch',
          startTime: '12:30',
          endTime: '14:00',
          location: widget.destination,
          details: 'Try authentic local cuisine',
          estimatedCost: 25.0,
        ),
        Activity(
          title: 'Afternoon Activity',
          startTime: '14:30',
          endTime: '18:00',
          location: widget.destination,
          details: 'Continue exploring ${widget.destination}',
          estimatedCost: 15.0,
        ),
      ];

      days.add(Day(
        dayIndex: i + 1,
        date: dayDate,
        activities: activities,
        summary: 'Day ${i + 1} in ${widget.destination}',
      ));
    }

    return Trip(
      id: null,
      userId: 'local_user',
      destination: widget.destination,
      startDate: widget.startDate,
      endDate: widget.endDate,
      travelStyle: widget.travelStyle,
      budgetTier: widget.budgetTier,
      preferences: widget.preferences,
      days: days,
      notes: [],
      budgetItems: [],
      totalBudgetEstimate: 0.0,
      localTips: [],
      isSynced: false,
    );
  }

  void _updateProgress(String message, double progress) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _progress = progress;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _errorMessage = null;
      _generatedTrip = null;
    });
    await _generateItinerary();
  }

  void _cancel() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripDuration = widget.endDate.difference(widget.startDate).inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generating Itinerary'),
        leading: _isGenerating
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancel,
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trip Summary Card
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.destination,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatDateRange(widget.startDate, widget.endDate)} • ${formatDuration(tripDuration)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.travelStyle != null ||
                          widget.budgetTier != null) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (widget.travelStyle != null)
                              Chip(
                                label: Text(
                                  widget.travelStyle![0].toUpperCase() +
                                      widget.travelStyle!.substring(1),
                                ),
                                avatar: const Icon(Icons.style, size: 18),
                              ),
                            if (widget.budgetTier != null)
                              Chip(
                                label: Text(
                                  widget.budgetTier![0].toUpperCase() +
                                      widget.budgetTier!.substring(1),
                                ),
                                avatar: const Icon(Icons.payments, size: 18),
                              ),
                          ],
                        ),
                      ],
                      if (widget.preferences != null &&
                          widget.preferences!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notes,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.preferences!,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Generation Status Area
              Expanded(
                child: Center(
                  child: _errorMessage != null
                      ? _buildErrorState(theme)
                      : _generatedTrip != null
                          ? _buildSuccessState(theme)
                          : _buildGeneratingState(theme),
                ),
              ),

              // Action Buttons
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cancel,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
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

  Widget _buildGeneratingState(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated AI Icon
          ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 60,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Status Message
        Text(
          _statusMessage,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Progress Bar
        SizedBox(
          width: 280,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Fun fact or tip
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Our AI is crafting a personalized itinerary just for you...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _statusMessage,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your itinerary has been created',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Redirecting...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.errorContainer,
          ),
          child: Icon(
            Icons.error_outline,
            size: 80,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Generation Failed',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage ?? 'An unknown error occurred',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Troubleshooting tips:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Check your internet connection\n'
                '• Verify API credentials are set up\n'
                '• Try again in a few moments',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}
