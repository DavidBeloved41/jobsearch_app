import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../jobs/screens/job_detail_screen.dart';
import 'post_job_screen.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _jobs = [];
        _isLoading = false;
        _error = 'Please sign in again.';
      });
      return;
    }

    try {
      final list = await SupabaseService.getJobsByPoster(userId);
      if (mounted) {
        setState(() {
          _jobs = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('MyJobsScreen: failed to load jobs: $e');
      if (mounted) {
        setState(() {
          _jobs = [];
          _isLoading = false;
          _error = 'Could not load your job postings.';
        });
      }
    }
  }

  Future<void> _deleteJob(String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete job'),
        content: const Text(
          'Are you sure you want to delete this job posting?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.deleteJob(jobId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Job deleted')));
      }
      await _loadJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  String _statusLabel(Map<String, dynamic> job) {
    final status = (job['approval_status'] ?? 'pending').toString();
    final active = job['is_active'] == true;
    if (status == 'approved' && active) return 'Approved';
    if (status == 'pending') return 'Pending';
    if (status == 'rejected') return 'Rejected';
    if (status == 'draft') return 'Draft';
    if (!active) return 'Inactive';
    return status;
  }

  Color _statusColor(Map<String, dynamic> job) {
    final status = (job['approval_status'] ?? 'pending').toString();
    final active = job['is_active'] == true;
    if (status == 'approved' && active) return AppColors.success;
    if (status == 'rejected') return AppColors.error;
    if (status == 'pending') return AppColors.warning;
    if (!active) return AppColors.textSec(context);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My job postings'),
        actions: [
          IconButton(
            onPressed: _loadJobs,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh jobs',
          ),
        ],
      ),
      backgroundColor: AppColors.bg(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadJobs,
              child: _error != null
                  ? _buildErrorState()
                  : _jobs.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        final title =
                            job['title']?.toString() ?? 'Untitled job';
                        final location =
                            job['location']?.toString() ?? 'Location not set';
                        final employmentType =
                            job['employment_type']?.toString() ??
                            'Not specified';
                        final workModel =
                            job['work_model']?.toString() ?? 'Not specified';
                        final createdAt = job['created_at']?.toString();
                        final statusLabel = _statusLabel(job);
                        final statusColor = _statusColor(job);

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppColors.bord(context)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.text(context),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '$location • $employmentType',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSec(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _infoPill('Work model', workModel),
                                    _infoPill(
                                      'Posted',
                                      createdAt != null
                                          ? createdAt.split('T').first
                                          : 'Unknown',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Applications: ${job['app_count'] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSec(context),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        job['is_active'] == true
                                            ? 'Active'
                                            : 'Inactive',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSec(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  JobDetailScreen(job: job),
                                            ),
                                          );
                                        },
                                        child: const Text('View job'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final result =
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PostJobScreen(job: job),
                                                ),
                                              );
                                          if (result != null) await _loadJobs();
                                        },
                                        child: const Text('Edit'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _deleteJob(job['id'] as String),
                                        child: const Text('Delete'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 52,
                  color: AppColors.textSec(context),
                ),
                const SizedBox(height: 16),
                Text(
                  'No jobs posted yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first job posting to start attracting candidates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSec(context)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PostJobScreen()),
                    );
                    await _loadJobs();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Post a job'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text(context)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadJobs,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
