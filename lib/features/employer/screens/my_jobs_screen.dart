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

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _jobs = [];
        _isLoading = false;
      });
      return;
    }
    final list = await SupabaseService.getJobsByPoster(userId);
    if (mounted) {
      setState(() {
        _jobs = list;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My job postings')),
      backgroundColor: AppColors.bg(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadJobs,
              child: _jobs.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No job postings yet',
                            style: TextStyle(color: AppColors.textSec(context)),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _jobs.length,
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        final company =
                            job['companies'] as Map<String, dynamic>?;
                        return ListTile(
                          title: Text(job['title'] as String? ?? 'Untitled'),
                          subtitle: Text(
                            '${company?['name'] ?? job['company_name'] ?? ''} • ${job['location'] ?? ''}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'view') {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => JobDetailScreen(job: job),
                                  ),
                                );
                              } else if (v == 'delete') {
                                _deleteJob(job['id'] as String);
                              } else if (v == 'edit') {
                                final res = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PostJobScreen(job: job),
                                  ),
                                );
                                if (res != null) await _loadJobs();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'view', child: Text('View')),
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
