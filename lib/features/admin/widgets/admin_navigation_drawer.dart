import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';

class AdminNavigationDrawer extends StatelessWidget {
  final String selectedRoute;

  const AdminNavigationDrawer({super.key, required this.selectedRoute});

  static const _destinations =
      <({String label, String route, IconData icon, IconData selectedIcon})>[
        (
          label: 'Dashboard',
          route: AppRoutes.adminDashboard,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
        (
          label: 'Jobs',
          route: AppRoutes.adminJobs,
          icon: Icons.work_outline,
          selectedIcon: Icons.work,
        ),
        (
          label: 'Users',
          route: AppRoutes.adminUsers,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
        ),
        (
          label: 'Applications',
          route: AppRoutes.adminApplications,
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surf(context),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primary,
                    child: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Admin workspace',
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.bord(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  for (final destination in _destinations)
                    _buildDestination(context, destination),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.bord(context)),
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.of(context).pop();
                await _confirmLogout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestination(
    BuildContext context,
    ({String label, String route, IconData icon, IconData selectedIcon})
    destination,
  ) {
    final selected = selectedRoute == destination.route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.10),
        selectedColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(selected ? destination.selectedIcon : destination.icon),
        title: Text(
          destination.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () {
          Navigator.of(context).pop();
          if (!selected) context.go(destination.route);
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access admin tools.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }
}
