import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/signup_screen.dart';
import 'edit_profile_screen.dart';
import 'resume_screen.dart';
import 'skills_screen.dart';
import 'skill_gap_screen.dart';
import 'saved_jobs_screen.dart';
import 'notifications_screen.dart';
import 'help_screen.dart';
import 'career_advice_screen.dart';
import 'profile_visibility_screen.dart';
import '../../employer/screens/employer_candidates_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;
  int _appliedCount = 0;
  int _interviewingCount = 0;
  int _offersCount = 0;
  bool _isOpenToWork = true;
  String? _profilePhotoUrl; // FIX: track photo URL in state
  String? _fullName; // FIX: load full_name from profiles table too

  @override
  void initState() {
    super.initState();
    user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          user = data.session?.user;
        });
        if (user != null) _loadStats();
      }
    });
    if (user != null) _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final userId = user!.id;
      final applications = await SupabaseService.getApplications(userId);
      final profile = await SupabaseService.getProfile(userId);
      if (mounted) {
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
          _isOpenToWork = profile?['is_open_to_work'] ?? true;
          // FIX: load photo URL and full name from profile
          _profilePhotoUrl = profile?['profile_photo_url'];
          _fullName = profile?['full_name'];
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _signOut() async {
    await BiometricService.disableBiometric();
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Join SmartJob',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to track your applications, save jobs, message recruiters and more.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSec(context),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // FIX: derive display name — prefer profiles.full_name, fallback to metadata
    final displayName = _fullName?.isNotEmpty == true
        ? _fullName!
        : (user?.userMetadata?['full_name'] ?? 'Your Name');

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
              color: AppColors.surf(context),
              child: Column(
                children: [
                  // FIX: show actual photo if available, fallback to icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      image: _profilePhotoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_profilePhotoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profilePhotoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSec(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isOpenToWork)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: AppColors.success),
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
              color: AppColors.surf(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Applied', value: '$_appliedCount'),
                  _VerticalDivider(),
                  _StatItem(label: 'Interviews', value: '$_interviewingCount'),
                  _VerticalDivider(),
                  _StatItem(label: 'Offers', value: '$_offersCount'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Menu items
            Container(
              color: AppColors.surf(context),
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.person_outlined,
                    label: 'Edit profile',
                    // FIX: reload stats (including photo) when returning
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        )
                        .then((_) => _loadStats()),
                  ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                    label: 'My resume',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ResumeScreen()),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.school_outlined,
                    label: 'Skills & experience',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SkillsScreen()),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.insights_outlined,
                    label: 'Skill gap analysis',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SkillGapScreen(),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.bookmark_outlined,
                    label: 'Saved jobs',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SavedJobsScreen(),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.visibility_outlined,
                    label: 'Profile visibility',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileVisibilityScreen(),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.people_outline,
                    label: 'Browse candidates (Employer)',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmployerCandidatesScreen(),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Career advice',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CareerAdviceScreen(),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Container(
              color: AppColors.surf(context),
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
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 40, width: 1, color: AppColors.bord(context));
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
          color: color == AppColors.textPrimary
              ? AppColors.text(context)
              : color,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: color == AppColors.textPrimary
          ? Icon(Icons.chevron_right, color: AppColors.textSec(context))
          : null,
      onTap: onTap,
    );
  }
}
