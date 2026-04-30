import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_service.dart';
import 'edit_profile_screen.dart';
import 'resume_screen.dart';
import 'skills_screen.dart';
import 'saved_jobs_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  int _appliedCount = 0;
  int _interviewingCount = 0;
  int _offersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final applications = await SupabaseService.getApplications(userId);
      setState(() {
        _appliedCount = applications
            .where((a) => a['status'] == 'applied')
            .length;
        _interviewingCount = applications
            .where((a) => a['status'] == 'interviewing')
            .length;
        _offersCount = applications
            .where((a) => a['status'] == 'offered')
            .length;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      GoRouter.of(context).go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: AppColors.surface,
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    user?.userMetadata?['full_name'] ?? 'Your Name',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Open to work badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: 8, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'Open to work',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Stats row
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Applied', value: '$_appliedCount'),
_Divider(),
_StatItem(label: 'Interviews', value: '$_interviewingCount'),
_Divider(),
_StatItem(label: 'Offers', value: '$_offersCount'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Menu items
            Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  _MenuItem(
                   icon: Icons.person_outlined,
                    label: 'Edit profile',
                     onTap: () {
                      Navigator.of(context).push(
                       MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                 ),
               );
              },
            ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                     label: 'My resume',
                      onTap: () {
                        Navigator.of(context).push(
                         MaterialPageRoute(
                          builder: (_) => const ResumeScreen(),
                   ),
                  );
                },
              ),
                  _MenuItem(
                    icon: Icons.school_outlined,
                    label: 'Skills & experience',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SkillsScreen(),
                 ),
               );
             },
            ),
                  _MenuItem(
                    icon: Icons.bookmark_outlined,
                     label: 'Saved jobs',
                      onTap: () {
                       Navigator.of(context).push(
                        MaterialPageRoute(
                         builder: (_) => const SavedJobsScreen(),
                    ),
                  );
                },
              ),
                 _MenuItem(
                   icon: Icons.notifications_outlined,
                    label: 'Notifications',
                     onTap: () {
                      Navigator.of(context).push(
                       MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                   ),
                 );
               },
              ),
                  _MenuItem(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Sign out
            Container(
              color: AppColors.surface,
              child: _MenuItem(
                icon: Icons.logout,
                label: 'Sign out',
                onTap: _signOut,
                color: AppColors.error,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.border,
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _MenuItem({
    required this.icon,
    required this.label,
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
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: color == AppColors.textPrimary
          ? const Icon(Icons.chevron_right, color: AppColors.textHint)
          : null,
      onTap: onTap,
    );
  }
}