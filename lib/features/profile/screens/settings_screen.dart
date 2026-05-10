import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _jobAlerts = true;
  bool _messageNotifications = true;
  bool _applicationUpdates = true;
  bool _emailNotifications = true;
  bool _isLoading = true;

  // FIX: Added _profileVisibility state (was missing before)
  String _profileVisibility = 'everyone';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profile = await SupabaseService.getProfile(userId);
      if (profile != null) {
        setState(() {
          _jobAlerts = profile['notify_job_alerts'] ?? true;
          _messageNotifications = profile['notify_messages'] ?? true;
          _applicationUpdates = profile['notify_application_updates'] ?? true;
          _emailNotifications = profile['notify_email'] ?? true;

          // FIX: Load profile_visibility; handles legacy bool + new string values
          final vis = profile['profile_visibility'];
          if (vis is bool) {
            _profileVisibility = vis ? 'everyone' : 'nobody';
          } else if (vis is String) {
            _profileVisibility = vis;
          } else {
            _profileVisibility = 'everyone';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // FIX: Changed bool to dynamic so it can save strings too
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await SupabaseService.updateProfile(userId, {
        key: value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save setting'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showProfileVisibilityDialog() {
    // FIX: Use loaded value instead of always defaulting to 'everyone'
    String selected = _profileVisibility;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile visibility',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _VisibilityOption(
                    title: 'Everyone',
                    subtitle: 'All verified employers can see your profile',
                    isSelected: selected == 'everyone',
                    onTap: () async {
                      setModalState(() => selected = 'everyone');
                      final parentContext = this.context;
                      final navigator = Navigator.of(parentContext);
                      final messenger = ScaffoldMessenger.of(parentContext);
                      // FIX: Save string not bool; update parent state immediately
                      await _saveSetting('profile_visibility', 'everyone');
                      if (!mounted) return;
                      setState(() => _profileVisibility = 'everyone');
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Profile visibility updated'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _VisibilityOption(
                    title: 'Nobody',
                    subtitle: 'Hide your profile from employers',
                    isSelected: selected == 'nobody',
                    onTap: () async {
                      setModalState(() => selected = 'nobody');
                      final parentContext = this.context;
                      final navigator = Navigator.of(parentContext);
                      final messenger = ScaffoldMessenger.of(parentContext);
                      // FIX: Save string not bool; update parent state immediately
                      await _saveSetting('profile_visibility', 'nobody');
                      if (!mounted) return;
                      setState(() => _profileVisibility = 'nobody');
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Profile visibility updated'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBlockedUsersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Blocked users',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.block_outlined,
                size: 48,
                color: AppColors.textSec(context),
              ),
              const SizedBox(height: 16),
              Text(
                'No blocked users',
                style: TextStyle(color: AppColors.textSec(context)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_reset_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Change password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We will send a password reset link to your email address.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSec(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            final email = Supabase
                                .instance
                                .client
                                .auth
                                .currentUser
                                ?.email;
                            if (email == null) return;
                            setModalState(() => isSending = true);
                            try {
                              // FIX: redirectTo stops the link opening localhost.
                              // Also add 'smartjob://reset-password' in:
                              // Supabase Dashboard -> Authentication ->
                              // URL Configuration -> Redirect URLs
                              await Supabase.instance.client.auth
                                  .resetPasswordForEmail(
                                    email,
                                    redirectTo: 'smartjob://reset-password',
                                  );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password reset link sent to your email!',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSending = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    child: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Send reset link'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _downloadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profile = await SupabaseService.getProfile(userId);
      final applications = await SupabaseService.getApplications(userId);
      final savedJobs = await SupabaseService.getSavedJobs(userId);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surf(context),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Data Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DataRow(
                    label: 'Name',
                    value: profile?['full_name'] ?? 'N/A',
                  ),
                  _DataRow(
                    label: 'Email',
                    value:
                        Supabase.instance.client.auth.currentUser?.email ??
                        'N/A',
                  ),
                  _DataRow(
                    label: 'Location',
                    value: profile?['location'] ?? 'N/A',
                  ),
                  _DataRow(
                    label: 'Applications',
                    value: '${applications.length}',
                  ),
                  _DataRow(label: 'Saved Jobs', value: '${savedJobs.length}'),
                  _DataRow(
                    label: 'Exported at',
                    value: DateTime.now().toString().substring(0, 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please contact support@jobsearch.app to delete your account.',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // FIX: Getter so the subtitle on the tile shows the current saved value
  String get _visibilityLabel =>
      _profileVisibility == 'everyone' ? 'Everyone' : 'Nobody';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(label: 'Notifications'),
                  Container(
                    color: AppColors.surf(context),
                    child: Column(
                      children: [
                        _SwitchTile(
                          icon: Icons.work_outline,
                          label: 'Job alerts',
                          subtitle: 'Get notified about high match jobs',
                          value: _jobAlerts,
                          onChanged: (value) {
                            setState(() => _jobAlerts = value);
                            _saveSetting('notify_job_alerts', value);
                          },
                        ),
                        _Divider(),
                        _SwitchTile(
                          icon: Icons.chat_bubble_outline,
                          label: 'Messages',
                          subtitle: 'Get notified about new messages',
                          value: _messageNotifications,
                          onChanged: (value) {
                            setState(() => _messageNotifications = value);
                            _saveSetting('notify_messages', value);
                          },
                        ),
                        _Divider(),
                        _SwitchTile(
                          icon: Icons.assignment_outlined,
                          label: 'Application updates',
                          subtitle: 'Get notified about your applications',
                          value: _applicationUpdates,
                          onChanged: (value) {
                            setState(() => _applicationUpdates = value);
                            _saveSetting('notify_application_updates', value);
                          },
                        ),
                        _Divider(),
                        _SwitchTile(
                          icon: Icons.email_outlined,
                          label: 'Email notifications',
                          subtitle: 'Receive updates via email',
                          value: _emailNotifications,
                          onChanged: (value) {
                            setState(() => _emailNotifications = value);
                            _saveSetting('notify_email', value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const _SectionHeader(label: 'Appearance'),
                  Container(
                    color: AppColors.surf(context),
                    child: _SwitchTile(
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark mode',
                      subtitle: 'Switch to dark theme',
                      value: isDarkMode,
                      onChanged: (value) {
                        ref.read(themeProvider.notifier).toggleTheme(value);
                      },
                    ),
                  ),

                  const _SectionHeader(label: 'Privacy'),
                  Container(
                    color: AppColors.surf(context),
                    child: Column(
                      children: [
                        // FIX: subtitle now shows current saved visibility
                        _TapTile(
                          icon: Icons.visibility_outlined,
                          label: 'Profile visibility',
                          subtitle: 'Currently visible to: $_visibilityLabel',
                          onTap: _showProfileVisibilityDialog,
                        ),
                        _Divider(),
                        _TapTile(
                          icon: Icons.block_outlined,
                          label: 'Blocked users',
                          subtitle: 'Manage blocked accounts',
                          onTap: _showBlockedUsersDialog,
                        ),
                      ],
                    ),
                  ),

                  const _SectionHeader(label: 'Account'),
                  Container(
                    color: AppColors.surf(context),
                    child: Column(
                      children: [
                        _TapTile(
                          icon: Icons.lock_outlined,
                          label: 'Change password',
                          subtitle: 'Update your password',
                          onTap: _showChangePasswordDialog,
                        ),
                        _Divider(),
                        _TapTile(
                          icon: Icons.download_outlined,
                          label: 'Download my data',
                          subtitle: 'Get a copy of your data',
                          onTap: _downloadData,
                        ),
                        _Divider(),
                        _TapTile(
                          icon: Icons.delete_outline,
                          label: 'Delete account',
                          subtitle: 'Permanently delete your account',
                          onTap: _showDeleteAccountDialog,
                          color: AppColors.error,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _VisibilityOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.bg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.bord(context),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSec(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.text(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textSec(context)),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        activeThumbColor: AppColors.primary, // keep thumb color
      ),
    );
  }
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _TapTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color == AppColors.textPrimary
              ? AppColors.text(context)
              : color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textSec(context)),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSec(context)),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 56, color: AppColors.bord(context));
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppColors.textSec(context)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.text(context),
            ),
          ),
        ],
      ),
    );
  }
}
