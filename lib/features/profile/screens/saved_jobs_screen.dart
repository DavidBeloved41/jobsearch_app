import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../jobs/screens/job_detail_screen.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<Map<String, dynamic>> _savedJobs = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadSavedJobs();
  }

  Future<void> _loadSavedJobs() async {
    setState(() => _isLoading = true);
    final connectivity = await Connectivity().checkConnectivity();
    final online = !connectivity.contains(ConnectivityResult.none);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _savedJobs = [];
        _userId = null;
        _isLoading = false;
      });
      return;
    }

    _userId = user.id;

    try {
      final userId = user.id;
      if (online) {
        final savedJobs = await SupabaseService.getSavedJobs(userId);
        await OfflineCacheService.cacheSavedJobs(savedJobs);
        setState(() {
          _savedJobs = savedJobs;
          _isOffline = false;
          _isLoading = false;
        });
      } else {
        throw Exception('offline');
      }
    } catch (e) {
      final cached = await OfflineCacheService.getCachedSavedJobs();
      setState(() {
        _savedJobs = cached ?? [];
        _isOffline = cached != null;
        _isLoading = false;
      });
      if (cached == null) debugPrint('Error loading saved jobs: $e');
    }
  }

  Future<void> _unsaveJob(String userId, String jobId) async {
    try {
      await SupabaseService.unsaveJob(userId, jobId);
      await _loadSavedJobs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job removed from saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error unsaving job: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Saved Jobs'),
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.warning.withValues(alpha: 0.12),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Text('Offline — cached saved jobs'),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _savedJobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: AppColors.textSec(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved jobs yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bookmark jobs you\'re interested in',
                        style: TextStyle(
                          color: AppColors.textSec(context),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSavedJobs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _savedJobs.length,
                    itemBuilder: (context, index) {
                      final savedJob = _savedJobs[index];
                      final job =
                          savedJob['jobs'] as Map<String, dynamic>?;
                      final company =
                          job?['companies'] as Map<String, dynamic>?;
                      return GestureDetector(
                        onTap: () {
                          if (job != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(job: job),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surf(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.bord(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.business,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job?['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      company?['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSec(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: AppColors.textSec(context),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          job?['location'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppColors.textSec(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.bookmark,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                                onPressed: _userId == null
                                    ? null
                                    : () => _unsaveJob(
                                          _userId!,
                                          job?['id'] ?? '',
                                        ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}