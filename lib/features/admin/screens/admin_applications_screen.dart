import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../widgets/admin_navigation_drawer.dart';

class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _statuses = [
    'all',
    'applied',
    'interviewing',
    'offered',
    'declined',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase(),
        );
      }
    });
    _loadApplications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await SupabaseService.getAllApplications();
      if (mounted) {
        setState(() {
          _applications = apps;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
        debugPrint('Error loading applications: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredApplications {
    return _applications.where((application) {
      final statusMatches =
          _filterStatus == 'all' || application['status'] == _filterStatus;
      final applicant = application['profiles'] as Map<String, dynamic>?;
      final job = application['jobs'] as Map<String, dynamic>?;
      final haystack = '${applicant?['full_name'] ?? ''} ${job?['title'] ?? ''}'
          .toLowerCase();
      return statusMatches &&
          (_searchQuery.isEmpty || haystack.contains(_searchQuery));
    }).toList();
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
          title: const Text('Application Management'),
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
        drawer: const AdminNavigationDrawer(
          selectedRoute: AppRoutes.adminApplications,
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.surf(context),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search candidates or jobs',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statuses.map((status) {
                        final isSelected = _filterStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              status == 'all' ? 'All' : status.toUpperCase(),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _filterStatus = status);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null && !_loading
                  ? Center(
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
                            'Error loading applications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We could not load applications. Check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSec(context),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadApplications,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredApplications.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No applications found',
                      message:
                          'Candidate applications will appear here as they arrive.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredApplications.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApplications[index];
                        final applicant =
                            app['profiles'] as Map<String, dynamic>?;
                        final job = app['jobs'] as Map<String, dynamic>?;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppColors.bord(context)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.10,
                              ),
                              foregroundColor: AppColors.primary,
                              child: const Icon(Icons.person_outline),
                            ),
                            title: Text(
                              applicant?['full_name'] ?? 'Unknown Applicant',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Role: ${applicant?['job_title'] ?? 'Not specified'}',
                                ),
                                Text(
                                  'Applied for: ${job?['title'] ?? 'Unknown Job'}',
                                ),
                                Row(
                                  children: [
                                    AppStatusBadge(
                                      label: (app['status'] ?? 'pending')
                                          .toString(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Applied: ${_formatAppliedAt(app['applied_at'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSec(context),
                                      ),
                                    ),
                                    if (app['match_score'] != null)
                                      Text('Match: ${app['match_score']}%'),
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAppliedAt(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date?.toString().split('.').first ?? 'Unknown date';
  }
}
