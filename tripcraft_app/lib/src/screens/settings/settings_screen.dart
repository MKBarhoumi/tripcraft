// settings_screen.dart
// Screen for app settings, preferences, and account management
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/providers.dart';
import '../../constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  String _defaultBudgetTier = 'Budget';
  String _defaultTravelStyle = 'Relaxed';
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPackageInfo();
  }

  Future<void> _loadSettings() async {
    // In a real app, load from shared preferences
    setState(() {
      _themeMode = ThemeMode.system;
      _notificationsEnabled = true;
      _defaultBudgetTier = 'Budget';
      _defaultTravelStyle = 'Relaxed';
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _saveSettings() async {
    // In a real app, save to shared preferences
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // In a real app, call API to delete account
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion requested'),
          backgroundColor: Colors.red,
        ),
      );
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _clearLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Data'),
        content: const Text(
          'Are you sure you want to clear all local data? This will delete all offline trips that haven\'t been synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final storageService = ref.read(localStorageServiceProvider);
        await storageService.clearAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local data cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing data: $e')),
          );
        }
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: appName,
      applicationVersion: _packageInfo?.version ?? '1.0.0',
      applicationIcon: const Icon(Icons.flight_takeoff, size: 48),
      children: [
        const SizedBox(height: 16),
        const Text(
          'An AI-powered travel itinerary planning app that helps you create, manage, and optimize your trips.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Built with Flutter and powered by Groq AI.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User Profile Section
          if (authState.user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      (authState.user!.name?.isNotEmpty == true
                              ? authState.user!.name![0]
                              : authState.user!.email[0])
                          .toUpperCase(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authState.user!.name ?? 'User',
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    authState.user!.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // Appearance Section
          _buildSectionHeader('Appearance'),
          ListTile(
            key: const Key('theme_tile'),
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(_themeMode == ThemeMode.system
                ? 'System Default'
                : _themeMode == ThemeMode.light
                    ? 'Light'
                    : 'Dark'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(),
          ),

          // Preferences Section
          _buildSectionHeader('Preferences'),
          SwitchListTile(
            key: const Key('notifications_switch'),
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Enable trip reminders and updates'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSettings();
            },
          ),
          ListTile(
            key: const Key('budget_tier_tile'),
            leading: const Icon(Icons.attach_money),
            title: const Text('Default Budget Tier'),
            subtitle: Text(_defaultBudgetTier),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBudgetTierDialog(),
          ),
          ListTile(
            key: const Key('travel_style_tile'),
            leading: const Icon(Icons.style),
            title: const Text('Default Travel Style'),
            subtitle: Text(_defaultTravelStyle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTravelStyleDialog(),
          ),

          // Data & Storage Section
          _buildSectionHeader('Data & Storage'),
          ListTile(
            key: const Key('clear_data_tile'),
            leading: const Icon(Icons.delete_sweep, color: Colors.orange),
            title: const Text('Clear Local Data'),
            subtitle: const Text('Delete all offline trips'),
            onTap: _clearLocalData,
          ),

          // Account Section
          _buildSectionHeader('Account'),
          ListTile(
            key: const Key('logout_tile'),
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _handleLogout,
          ),
          ListTile(
            key: const Key('delete_account_tile'),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _handleDeleteAccount,
          ),

          // About Section
          _buildSectionHeader('About'),
          ListTile(
            key: const Key('about_tile'),
            leading: const Icon(Icons.info),
            title: const Text('About $appName'),
            subtitle: Text('Version ${_packageInfo?.version ?? '1.0.0'}'),
            onTap: _showAboutDialog,
          ),
          ListTile(
            key: const Key('privacy_tile'),
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy policy would open here'),
                ),
              );
            },
          ),
          ListTile(
            key: const Key('terms_tile'),
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terms of service would open here'),
                ),
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: _themeMode,
              onChanged: (value) {
                setState(() => _themeMode = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: _themeMode,
              onChanged: (value) {
                setState(() => _themeMode = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: _themeMode,
              onChanged: (value) {
                setState(() => _themeMode = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetTierDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Budget Tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Budget', 'Moderate', 'Luxury']
              .map((tier) => RadioListTile<String>(
                    title: Text(tier),
                    value: tier,
                    groupValue: _defaultBudgetTier,
                    onChanged: (value) {
                      setState(() => _defaultBudgetTier = value!);
                      _saveSettings();
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showTravelStyleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Travel Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Relaxed', 'Moderate', 'Fast-paced']
              .map((style) => RadioListTile<String>(
                    title: Text(style),
                    value: style,
                    groupValue: _defaultTravelStyle,
                    onChanged: (value) {
                      setState(() => _defaultTravelStyle = value!);
                      _saveSettings();
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
