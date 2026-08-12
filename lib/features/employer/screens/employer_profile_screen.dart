import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/post_job_screen.dart';
import '../screens/my_jobs_screen.dart';
import '../../messages/screens/messages_screen.dart';

class EmployerProfileScreen extends StatefulWidget {
  const EmployerProfileScreen({super.key});

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> {
  String? _companyName;
  int _jobsPosted = 0;
  int _applicants = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployerData();
  }

  Future<void> _loadEmployerData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final profile = await SupabaseService.getProfile(userId);
      final jobs = await SupabaseService.getJobsByPoster(userId);
      final applicants = await SupabaseService.getApplicantCountForPoster(
        userId,
      );
      if (mounted) {
        setState(() {
          _companyName = profile?['company_name'] as String?;
          _jobsPosted = jobs.length;
          _applicants = applicants;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading employer data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Employer profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surf(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.bord(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _companyName ?? 'Your company',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage your jobs, view applications and message candidates.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSec(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatItem(label: 'Jobs', value: '$_jobsPosted'),
                            const SizedBox(width: 16),
                            _StatItem(
                              label: 'Applicants',
                              value: '$_applicants',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    icon: Icons.post_add_outlined,
                    title: 'Post a job',
                    subtitle: 'Create a new job posting',
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const PostJobScreen(),
                          ),
                        )
                        .then((_) => _loadEmployerData()),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.assignment_outlined,
                    title: 'My postings & applications',
                    subtitle: 'View your jobs and received applications',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyJobsScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.message_outlined,
                    title: 'Messages',
                    subtitle: 'Message candidates and view conversations',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MessagesScreen()),
                    ),
                  ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.textSec(context))),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bord(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppColors.textSec(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSec(context)),
          ],
        ),
      ),
    );
  }
}
