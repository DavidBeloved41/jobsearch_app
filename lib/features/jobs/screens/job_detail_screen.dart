import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/match_score_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/company_logo.dart';
import '../../auth/screens/login_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isApplying = false;
  bool _isSaved = false;
  bool _hasApplied = false;
  int _matchScore = 0;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
    _checkIfApplied();
    _loadMatchScore();
  }

  Future<void> _loadMatchScore() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _matchScore = MatchScoreService.calculate(job: widget.job, userSkillNames: []));
      return;
    }
    final profile = await SupabaseService.getProfile(userId);
    final skills = await SupabaseService.getUserSkillNames(userId);
    final years = profile?['years_of_experience'];
    final userYears = years is int ? years : int.tryParse('$years');
    if (mounted) {
      setState(() {
        _matchScore = MatchScoreService.calculate(
          job: widget.job,
          userSkillNames: skills,
          userYearsExperience: userYears,
        );
      });
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user ID available for checking saved jobs');
        return;
      }
      debugPrint(
        'Checking if job ${widget.job['id']} is saved for user $userId',
      );
      final saved = await SupabaseService.getSavedJobs(userId);
      if (mounted) {
        final isSaved = saved.any((s) => s['job_id'] == widget.job['id']);
        setState(() => _isSaved = isSaved);
        debugPrint('Job saved status: $isSaved');
      }
    } catch (e) {
      debugPrint('Error checking saved: $e');
    }
  }

  Future<void> _checkIfApplied() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user ID available for checking applications');
        return;
      }
      debugPrint(
        'Checking if user $userId has applied for job ${widget.job['id']}',
      );
      final applications = await SupabaseService.getApplications(userId);
      if (mounted) {
        final hasApplied = applications.any(
          (a) => a['job_id'] == widget.job['id'],
        );
        setState(() => _hasApplied = hasApplied);
        debugPrint('Job application status: $hasApplied');
      }
    } catch (e) {
      debugPrint('Error checking application: $e');
    }
  }

  Future<String?> _promptCoverLetter() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply for this job'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Cover letter (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(context, text.isEmpty ? '' : text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyForJob() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('No user available for job application');
      _showLoginPrompt();
      return;
    }

    final coverLetter = await _promptCoverLetter();
    if (coverLetter == null || !mounted) return;

    setState(() => _isApplying = true);
    try {
      debugPrint('Applying for job ${widget.job['id']} with user ${user.id}');
      await SupabaseService.applyForJob(
        user.id,
        widget.job['id'],
        coverLetter.isEmpty ? null : coverLetter,
      );
      if (mounted) {
        setState(() {
          _hasApplied = true;
          _isApplying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying for job: $e');
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('duplicate')
                  ? 'You have already applied for this job'
                  : 'Failed to apply. Please try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('No user available for save job operation');
      _showLoginPrompt();
      return;
    }

    try {
      if (_isSaved) {
        debugPrint('Unsaving job ${widget.job['id']} for user ${user.id}');
        await SupabaseService.unsaveJob(user.id, widget.job['id']);
      } else {
        debugPrint('Saving job ${widget.job['id']} for user ${user.id}');
        await SupabaseService.saveJob(user.id, widget.job['id']);
      }
      if (mounted) {
        setState(() => _isSaved = !_isSaved);
      }
    } catch (e) {
      debugPrint('Error saving job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save job. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showLoginPrompt() {
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to sign in to apply for jobs and save them.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSec(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe later'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.job['companies'] as Map<String, dynamic>?;
    final workModel = widget.job['work_model'] ?? '';
    final salaryMin = widget.job['salary_min'] ?? 0;
    final salaryMax = widget.job['salary_max'] ?? 0;
    final currency = widget.job['salary_currency'] ?? 'USD';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _isSaved ? AppColors.primary : AppColors.textSec(context),
            ),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: Column(
                children: [
                  CompanyLogo(
                    logoUrl: company?['logo_url'] as String?,
                    size: 70,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.job['title'] ?? '',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    company?['name'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSec(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_matchScore% match',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label: widget.job['location'] ?? '',
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(icon: Icons.work_outline, label: workModel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _InfoChip(
                    icon: Icons.attach_money,
                    label:
                        '$currency ${(salaryMin / 1000).toStringAsFixed(0)}k - ${(salaryMax / 1000).toStringAsFixed(0)}k',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About the role
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About the role',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.job['description'] ?? 'No description available.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSec(context),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Job details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Job details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.business_center_outlined,
                    label: 'Employment type',
                    value: widget.job['employment_type'] ?? '',
                  ),
                  _DetailRow(
                    icon: Icons.bar_chart_outlined,
                    label: 'Experience level',
                    value: widget.job['experience_level'] ?? '',
                  ),
                  _DetailRow(
                    icon: Icons.location_city_outlined,
                    label: 'Industry',
                    value: company?['industry'] ?? '',
                  ),
                  _DetailRow(
                    icon: Icons.star_outline,
                    label: 'Company rating',
                    value: '${company?['average_rating'] ?? 'N/A'} / 5.0',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Apply button
            ElevatedButton(
              onPressed: _hasApplied || _isApplying ? null : _applyForJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasApplied
                    ? AppColors.success
                    : AppColors.primary,
              ),
              child: _isApplying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_hasApplied ? 'Applied ✓' : 'Apply Now'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSec(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSec(context),
                ),
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
        ],
      ),
    );
  }
}
