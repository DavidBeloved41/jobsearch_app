import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../widgets/admin_navigation_drawer.dart';

class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = [
    'all',
    'pending',
    'approved',
    'rejected',
    'active',
    'inactive',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugPrint('[ADMIN JOBS] Loading all jobs for admin...');
      final jobs = await SupabaseService.getAllJobsForAdmin();
      debugPrint('[ADMIN JOBS] Loaded ${jobs.length} jobs');

      // STEP 2: Capture actual data returned
      for (int i = 0; i < jobs.length; i++) {
        final job = jobs[i];
        debugPrint('[ADMIN JOBS] ===== JOB $i START =====');
        debugPrint('[ADMIN JOBS] Full job object: $job');
        debugPrint('[ADMIN JOBS] id: ${job['id']}');
        debugPrint('[ADMIN JOBS] title: ${job['title']}');
        debugPrint('[ADMIN JOBS] description: ${job['description']}');
        debugPrint('[ADMIN JOBS] location: ${job['location']}');
        debugPrint('[ADMIN JOBS] work_model: ${job['work_model']}');
        debugPrint('[ADMIN JOBS] employment_type: ${job['employment_type']}');
        debugPrint('[ADMIN JOBS] salary_min: ${job['salary_min']}');
        debugPrint('[ADMIN JOBS] salary_max: ${job['salary_max']}');
        debugPrint('[ADMIN JOBS] approval_status: ${job['approval_status']}');
        debugPrint('[ADMIN JOBS] is_active: ${job['is_active']}');
        debugPrint('[ADMIN JOBS] poster_id: ${job['poster_id']}');
        debugPrint('[ADMIN JOBS] created_at: ${job['created_at']}');
        debugPrint('[ADMIN JOBS] updated_at: ${job['updated_at']}');
        debugPrint('[ADMIN JOBS] approved_at: ${job['approved_at']}');
        debugPrint('[ADMIN JOBS] approved_by: ${job['approved_by']}');
        debugPrint('[ADMIN JOBS] rejection_reason: ${job['rejection_reason']}');
        debugPrint('[ADMIN JOBS] employer exists: ${job['employer'] != null}');
        if (job['employer'] != null) {
          final employer = job['employer'] as Map<String, dynamic>;
          debugPrint('[ADMIN JOBS] employer.id: ${employer['id']}');
          debugPrint(
            '[ADMIN JOBS] employer.full_name: ${employer['full_name']}',
          );
          debugPrint('[ADMIN JOBS] employer.email: ${employer['email']}');
          debugPrint(
            '[ADMIN JOBS] employer.account_type: ${employer['account_type']}',
          );
        }
        debugPrint('[ADMIN JOBS] profiles exists: ${job['profiles'] != null}');
        debugPrint('[ADMIN JOBS] ===== JOB $i END =====');
      }

      if (mounted) {
        setState(() {
          _allJobs = jobs;
          _loading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
        debugPrint('[ADMIN JOBS] Error loading jobs: $e');
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    final query = _searchQuery.toLowerCase();
    final filtered = _allJobs.where((job) {
      // Apply status/active filter
      bool matchesFilter = true;
      if (_selectedFilter != 'all') {
        final status = job['approval_status'] as String?;
        final isActive = job['is_active'] as bool?;

        if (_selectedFilter == 'pending') {
          matchesFilter = status == 'pending';
        } else if (_selectedFilter == 'approved') {
          matchesFilter = status == 'approved';
        } else if (_selectedFilter == 'rejected') {
          matchesFilter = status == 'rejected';
        } else if (_selectedFilter == 'active') {
          matchesFilter = isActive == true && status == 'approved';
        } else if (_selectedFilter == 'inactive') {
          matchesFilter = isActive == false || status != 'approved';
        }
      }

      if (!matchesFilter) return false;

      // Apply search filter
      if (query.isEmpty) return true;

      final title = (job['title'] as String?)?.toLowerCase() ?? '';
      final location = (job['location'] as String?)?.toLowerCase() ?? '';
      final employer =
          (job['employer'] as Map<String, dynamic>?)?['full_name']
              ?.toString()
              .toLowerCase() ??
          '';

      return title.contains(query) ||
          location.contains(query) ||
          employer.contains(query);
    }).toList();

    if (mounted) {
      setState(() => _filteredJobs = filtered);
    }
  }

  /// STEP 3: Defensive ListView builder with proper error handling
  Widget _buildJobsList(BuildContext context) {
    debugPrint(
      '[ADMIN JOBS] Building list with ${_filteredJobs.length} filtered jobs',
    );

    try {
      if (_filteredJobs.isEmpty) {
        return const AppEmptyState(
          icon: Icons.work_outline,
          title: 'No jobs found',
          message: 'Approved and pending job postings will appear here.',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredJobs.length,
        itemBuilder: (context, index) {
          try {
            final job = _filteredJobs[index];
            debugPrint(
              '[ADMIN JOBS] Building card for job index=$index, id=${job['id']}',
            );

            // STEP 3: Defensive field extraction
            final jobId = job['id']?.toString() ?? '';
            final title = job['title']?.toString() ?? 'Untitled';
            final employer = job['employer'] as Map<String, dynamic>?;
            final status = job['approval_status']?.toString() ?? 'pending';
            final isActive = job['is_active'] as bool?;
            final location = job['location']?.toString() ?? 'N/A';
            final workModel = job['work_model']?.toString() ?? 'N/A';
            final createdAt = job['created_at']?.toString() ?? '';

            if (jobId.isEmpty) {
              debugPrint('[ADMIN JOBS] WARNING: Job at index $index has no ID');
            }

            return Card(
              child: ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Employer: ${employer?['full_name'] ?? 'Unknown'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('$location • $workModel'),
                    Row(
                      children: [
                        AppStatusBadge(label: status),
                        const SizedBox(width: 8),
                        AppStatusBadge(
                          label: isActive == true ? 'Active' : 'Closed',
                        ),
                      ],
                    ),
                    Text(
                      'Posted: ${_formatDate(createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSec(context),
                      ),
                    ),
                  ],
                ),
                trailing: status == 'pending'
                    ? TextButton(
                        onPressed: () => _showReviewDialog(job),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                        ),
                        child: const Text(
                          'Review',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    : null,
              ),
            );
          } catch (e) {
            debugPrint('[ADMIN JOBS] ERROR building card at index $index: $e');
            return Card(
              child: ListTile(
                title: const Text('Error loading job'),
                subtitle: Text('Error: ${e.toString()}'),
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('[ADMIN JOBS] CRITICAL ERROR building ListView: $e');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text('Error building jobs list'),
            SizedBox(height: 8),
            Text(
              'Try refreshing the page. If the problem continues, contact support.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.adminDashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(
          title: const Text('Job Management'),
          backgroundColor: AppColors.surf(context),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open admin navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Admin dashboard',
              onPressed: () => context.go(AppRoutes.adminDashboard),
            ),
          ],
        ),
        drawer: const AdminNavigationDrawer(selectedRoute: AppRoutes.adminJobs),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by title, location, or company...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
              ),
            ),

            // Filter chips
            Container(
              color: AppColors.surf(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter.toUpperCase()),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = filter);
                          _applyFilters();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Error state with retry
            if (_error != null && !_loading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading jobs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error ?? 'Unknown error',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSec(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadJobs,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filteredJobs.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No jobs found',
                    style: TextStyle(
                      color: AppColors.textSec(context),
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Expanded(child: _buildJobsList(context)),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'Unknown';
      final date = DateTime.parse(dateValue.toString());
      return date.toString().split('.')[0];
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showReviewDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AdminJobReviewDialog(
        job: job,
        onApprove: _handleApprove,
        onReject: _handleReject,
      ),
    );
  }

  Future<void> _handleApprove(String jobId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.approveJob(jobId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job approved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadJobs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error approving job: $e')));
      }
    }
  }

  Future<void> _handleReject(String jobId, String reason) async {
    try {
      await SupabaseService.rejectJob(jobId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job rejected successfully'),
            backgroundColor: AppColors.warning,
          ),
        );
        _loadJobs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error rejecting job: $e')));
      }
    }
  }
}

class AdminJobReviewDialog extends StatefulWidget {
  final Map<String, dynamic> job;
  final Function(String jobId) onApprove;
  final Function(String jobId, String reason) onReject;

  const AdminJobReviewDialog({
    super.key,
    required this.job,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<AdminJobReviewDialog> createState() => _AdminJobReviewDialogState();
}

class _AdminJobReviewDialogState extends State<AdminJobReviewDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    // STEP 6: Use correct field - job['employer'] not job['profiles']
    final employer = job['employer'] as Map<String, dynamic>?;

    // STEP 3: Defensive extraction of all required fields
    final title = job['title']?.toString() ?? 'Untitled Job';
    final employerName =
        employer?['full_name']?.toString() ?? 'Unknown Employer';
    final location = job['location']?.toString() ?? 'Location not specified';
    final workModel = job['work_model']?.toString() ?? 'Not specified';
    final employmentType =
        job['employment_type']?.toString() ?? 'Not specified';
    final salaryMin = job['salary_min'] is num
        ? job['salary_min'] as num
        : null;
    final salaryMax = job['salary_max'] is num
        ? job['salary_max'] as num
        : null;
    final description =
        job['description']?.toString() ?? 'No description provided';

    return AlertDialog(
      title: const Text('Review Job'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow('Title', title),
            _InfoRow('Employer', employerName),
            _InfoRow('Location', location),
            _InfoRow('Work Model', workModel),
            _InfoRow('Employment Type', employmentType),
            _InfoRow(
              'Salary',
              SupabaseService.formatSalaryDisplay(
                min: salaryMin,
                max: salaryMax,
                currency: job['salary_currency'] as String?,
                negotiable: (job['salary_negotiable'] as bool?) ?? false,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Rejection reason (if rejecting)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final jobId = job['id']?.toString();
            if (jobId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: Job ID not found')),
              );
              return;
            }
            widget.onApprove(jobId);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: const Text('Approve', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please provide a rejection reason'),
                ),
              );
              return;
            }
            final jobId = job['id']?.toString();
            if (jobId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: Job ID not found')),
              );
              return;
            }
            widget.onReject(jobId, _reasonController.text.trim());
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Reject', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
