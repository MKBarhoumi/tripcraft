// budget_tracker_screen.dart
// Screen for managing trip budget with category breakdown and expense tracking
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/trip.dart';
import '../../models/budget_item.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../providers/providers.dart';

class BudgetTrackerScreen extends ConsumerStatefulWidget {
  final String tripId;

  const BudgetTrackerScreen({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<BudgetTrackerScreen> createState() =>
      _BudgetTrackerScreenState();
}

class _BudgetTrackerScreenState extends ConsumerState<BudgetTrackerScreen> {
  Trip? _trip;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _editingItemId;

  // Controllers for add/edit forms
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Available budget categories
  final List<String> _categories = [
    'Accommodation',
    'Food & Dining',
    'Transportation',
    'Activities',
    'Shopping',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    setState(() => _isLoading = true);
    try {
      final storageService = ref.read(localStorageServiceProvider);
      final trip = await storageService.getTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trip: $e')),
        );
      }
    }
  }

  void _startAddingItem() {
    setState(() {
      _isEditing = true;
      _editingItemId = null;
      _categoryController.text = _categories.first;
      _amountController.clear();
      _descriptionController.clear();
    });
  }

  void _startEditingItem(BudgetItem item) {
    setState(() {
      _isEditing = true;
      _editingItemId = item.id;
      _categoryController.text = item.category;
      _amountController.text = item.amount.toString();
      _descriptionController.text = item.description ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingItemId = null;
      _categoryController.clear();
      _amountController.clear();
      _descriptionController.clear();
    });
  }

  Future<void> _saveBudgetItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text);
      final category = _categoryController.text;
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      List<BudgetItem> updatedItems = List.from(_trip!.budgetItems);

      if (_editingItemId != null) {
        // Update existing item
        final index = updatedItems.indexWhere((i) => i.id == _editingItemId);
        if (index != -1) {
          updatedItems[index] = updatedItems[index].copyWith(
            category: category,
            amount: amount,
            description: description,
          );
        }
      } else {
        // Add new item
        updatedItems.add(BudgetItem(
          category: category,
          amount: amount,
          description: description,
        ));
      }

      // Update trip
      final updatedTrip = _trip!.copyWith(
        budgetItems: updatedItems,
        isSynced: false,
        localUpdatedAt: DateTime.now(),
      );

      final storageService = ref.read(localStorageServiceProvider);
      await storageService.saveTrip(updatedTrip);

      if (mounted) {
        setState(() {
          _trip = updatedTrip;
          _isSaving = false;
        });
        _cancelEditing();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingItemId != null
                ? 'Budget item updated'
                : 'Budget item added'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget item: $e')),
        );
      }
    }
  }

  Future<void> _deleteBudgetItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget Item'),
        content: const Text('Are you sure you want to delete this budget item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final updatedItems = _trip!.budgetItems.where((i) => i.id != itemId).toList();
      final updatedTrip = _trip!.copyWith(
        budgetItems: updatedItems,
        isSynced: false,
        localUpdatedAt: DateTime.now(),
      );

      final storageService = ref.read(localStorageServiceProvider);
      await storageService.saveTrip(updatedTrip);

      if (mounted) {
        setState(() => _trip = updatedTrip);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget item deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting budget item: $e')),
        );
      }
    }
  }

  double _calculateTotalBudget() {
    return _trip?.budgetItems.fold<double>(0.0, (sum, item) => sum + item.amount) ?? 0.0;
  }

  double _calculateActualSpent() {
    return _trip?.calculateTotalCost() ?? 0.0;
  }

  double _calculateRemaining() {
    return _calculateTotalBudget() - _calculateActualSpent();
  }

  Map<String, double> _getBudgetByCategory() {
    final Map<String, double> categoryTotals = {};
    if (_trip != null) {
      for (final item in _trip!.budgetItems) {
        categoryTotals[item.category] =
            (categoryTotals[item.category] ?? 0.0) + item.amount;
      }
    }
    return categoryTotals;
  }

  Map<String, double> _getSpentByCategory() {
    final Map<String, double> categoryTotals = {};
    if (_trip != null) {
      for (final day in _trip!.days) {
        for (final activity in day.activities) {
          // Map activity costs to budget categories (simplified mapping)
          final category = _mapActivityToCategory(activity.title ?? 'Other');
          categoryTotals[category] =
              (categoryTotals[category] ?? 0.0) + activity.estimatedCost;
        }
      }
    }
    return categoryTotals;
  }

  String _mapActivityToCategory(String activityTitle) {
    final lower = activityTitle.toLowerCase();
    if (lower.contains('hotel') || lower.contains('accommodation')) {
      return 'Accommodation';
    } else if (lower.contains('restaurant') ||
        lower.contains('food') ||
        lower.contains('dining') ||
        lower.contains('meal')) {
      return 'Food & Dining';
    } else if (lower.contains('transport') ||
        lower.contains('taxi') ||
        lower.contains('bus') ||
        lower.contains('train') ||
        lower.contains('flight')) {
      return 'Transportation';
    } else if (lower.contains('shop') || lower.contains('store')) {
      return 'Shopping';
    } else if (lower.contains('museum') ||
        lower.contains('tour') ||
        lower.contains('attraction') ||
        lower.contains('activity')) {
      return 'Activities';
    }
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget Tracker')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget Tracker')),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final totalBudget = _calculateTotalBudget();
    final actualSpent = _calculateActualSpent();
    final remaining = _calculateRemaining();
    final budgetProgress = totalBudget > 0 ? actualSpent / totalBudget : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Tracker'),
        actions: [
          if (!_isEditing)
            IconButton(
              key: const Key('add_budget_item'),
              icon: const Icon(Icons.add),
              onPressed: _startAddingItem,
              tooltip: 'Add Budget Item',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Overview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryItem(
                          context,
                          'Total Budget',
                          formatCurrency(totalBudget),
                          Icons.account_balance_wallet,
                          Colors.blue,
                        ),
                        _buildSummaryItem(
                          context,
                          'Spent',
                          formatCurrency(actualSpent),
                          Icons.shopping_cart,
                          Colors.orange,
                        ),
                        _buildSummaryItem(
                          context,
                          'Remaining',
                          formatCurrency(remaining),
                          Icons.savings,
                          remaining >= 0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      key: const Key('budget_progress'),
                      value: budgetProgress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[300],
                      color: budgetProgress > 1.0
                          ? Colors.red
                          : budgetProgress > 0.8
                              ? Colors.orange
                              : Colors.green,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(budgetProgress * 100).toStringAsFixed(1)}% of budget used',
                      style: Theme.of(context).textTheme.bodySmall,
                      key: const Key('budget_percentage'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Add/Edit Form
            if (_isEditing) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingItemId != null
                              ? 'Edit Budget Item'
                              : 'Add Budget Item',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: const Key('category_dropdown'),
                          value: _categoryController.text.isEmpty
                              ? null
                              : _categoryController.text,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories
                              .map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _categoryController.text = value;
                            }
                          },
                          validator: (value) =>
                              validateRequired(value, 'Category'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('amount_field'),
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final required = validateRequired(value, 'Amount');
                            if (required != null) return required;
                            final amount = double.tryParse(value!);
                            if (amount == null) {
                              return 'Please enter a valid number';
                            }
                            if (amount < 0) {
                              return 'Amount must be positive';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('description_field'),
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLength: 200,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('cancel_button'),
                                onPressed: _isSaving ? null : _cancelEditing,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                key: const Key('save_button'),
                                onPressed: _isSaving ? null : _saveBudgetItem,
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Category Breakdown
            Text(
              'Budget by Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildCategoryBreakdown(),

            const SizedBox(height: 24),

            // Budget Items List
            Text(
              'Budget Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildBudgetItemsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    final budgetByCategory = _getBudgetByCategory();
    final spentByCategory = _getSpentByCategory();

    if (budgetByCategory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No budget items yet. Add items to track spending by category.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
            key: const Key('empty_categories'),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: budgetByCategory.entries.map((entry) {
          final category = entry.key;
          final budgeted = entry.value;
          final spent = spentByCategory[category] ?? 0.0;
          final progress = budgeted > 0 ? spent / budgeted : 0.0;

          return ListTile(
            key: Key('category_$category'),
            leading: Icon(
              _getCategoryIcon(category),
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(category),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[300],
                  color: progress > 1.0
                      ? Colors.red
                      : progress > 0.8
                          ? Colors.orange
                          : Colors.green,
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCurrency(spent)} / ${formatCurrency(budgeted)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBudgetItemsList() {
    if (_trip!.budgetItems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No budget items yet. Tap the + button to add one.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
            key: const Key('empty_budget_items'),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: _trip!.budgetItems.map((item) {
          return ListTile(
            key: Key('budget_item_${item.id}'),
            leading: Icon(
              _getCategoryIcon(item.category),
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(item.category),
            subtitle: item.description != null
                ? Text(item.description!)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatCurrency(item.amount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: Key('edit_item_${item.id}'),
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _startEditingItem(item),
                  tooltip: 'Edit',
                ),
                IconButton(
                  key: Key('delete_item_${item.id}'),
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _deleteBudgetItem(item.id),
                  tooltip: 'Delete',
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Accommodation':
        return Icons.hotel;
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Transportation':
        return Icons.directions_bus;
      case 'Activities':
        return Icons.local_activity;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Other':
      default:
        return Icons.more_horiz;
    }
  }
}
