import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/post_job_screen.dart';
import '../screens/my_jobs_screen.dart';
import '../../messages/screens/messages_screen.dart';

class EmployerDashboardScreen extends StatefulWidget {
  const EmployerDashboardScreen({super.key});

  @override
  State<EmployerDashboardScreen> createState() =>
      _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends State<EmployerDashboardScreen> {
  String? _companyName;
  String? _companyLogoUrl;
  int _jobsPosted = 0;
  int _totalApplicants = 0;
  int _activeJobs = 0;
  bool _loading = true;
  String _selectedTimeFilter = 'This month';
  List<Map<String, dynamic>> _recentApplications = [];
  final _timeFilters = ['This week', 'This month', 'This year', 'All time'];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final company = await SupabaseService.getEmployerProfile(userId);
      final jobs = await SupabaseService.getJobsByPoster(userId);
      final applicantCount = await SupabaseService.getApplicantCountForPoster(
        userId,
      );
      final activeJobCount = await SupabaseService.getActiveJobCountForPoster(
        userId,
      );
      final recentApps = await SupabaseService.getRecentApplicationsForPoster(
        userId,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _companyName = company?['company_name'] as String?;
          _companyLogoUrl = company?['logo_url'] as String?;
          _jobsPosted = jobs.length;
          _totalApplicants = applicantCount;
          _activeJobs = activeJobCount;
          _recentApplications = recentApps;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading employer dashboard: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(context),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Company Summary Card
                          if (_jobsPosted == 0)
                            _buildEmptyStateCard(context)
                          else
                            _buildCompanySummaryCard(context),

                          const SizedBox(height: 24),

                          // Statistics Section
                          _buildStatisticsSection(context),

                          const SizedBox(height: 24),

                          // Quick Actions
                          _buildQuickActionsSection(context),

                          const SizedBox(height: 24),

                          // Recent Activity
                          if (_recentApplications.isNotEmpty)
                            _buildRecentActivitySection(context),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surf(context),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: AppColors.bord(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage: _companyLogoUrl != null
                            ? NetworkImage(_companyLogoUrl!)
                            : null,
                        child: _companyLogoUrl == null
                            ? const Icon(
                                Icons.business_outlined,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _companyName?.trim().isNotEmpty == true
                                ? _companyName!
                                : 'Complete your company profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Employer Dashboard',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSec(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // Placeholder for notifications
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications coming soon'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No jobs posted yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first job posting to start attracting candidates',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSec(context)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PostJobScreen()))
                .then((_) => _loadDashboardData()),
            icon: const Icon(Icons.add),
            label: const Text('Post Your First Job'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySummaryCard(BuildContext context) {
    return Container(
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
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: const Icon(
                    Icons.business_outlined,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build your dream team',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSec(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push(AppRoutes.employerCompanyProfile),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            child: const Text(
              'View company profile',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            PopupMenuButton<String>(
              initialValue: _selectedTimeFilter,
              onSelected: (value) {
                setState(() => _selectedTimeFilter = value);
                // TODO: Filter data by time range when analytics are added
              },
              itemBuilder: (context) => _timeFilters
                  .map(
                    (filter) =>
                        PopupMenuItem(value: filter, child: Text(filter)),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.bord(context)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedTimeFilter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSec(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.textSec(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Manage your jobs, applications and connect with talent',
          style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(
              context,
              'Jobs Posted',
              '$_jobsPosted',
              Icons.work_outline,
            ),
            _buildStatCard(
              context,
              'Total Applicants',
              '$_totalApplicants',
              Icons.people_outlined,
            ),
            _buildStatCard(
              context,
              'Active Jobs',
              '$_activeJobs',
              Icons.check_circle_outlined,
            ),
            _buildStatCard(
              context,
              'Profile Views',
              '—',
              Icons.visibility_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSec(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          icon: Icons.post_add_outlined,
          title: 'Post a new job',
          subtitle: 'Create a job posting and find the perfect candidate',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PostJobScreen()))
              .then((_) => _loadDashboardData()),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          icon: Icons.assignment_outlined,
          title: 'My jobs & applications',
          subtitle: 'Manage your jobs and review applications',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyJobsScreen())),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          icon: Icons.message_outlined,
          title: 'Messages',
          subtitle: 'Chat with candidates and manage conversations',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          icon: Icons.person_outline,
          title: 'Company profile',
          subtitle: 'Update your company information and settings',
          onTap: () => context.push(AppRoutes.employerCompanyProfile),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Manage appearance, notifications and account security',
          onTap: () => context.push(AppRoutes.employerSettings),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSec(context),
                    ),
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

  Widget _buildRecentActivitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bord(context)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentApplications.length,
            separatorBuilder: (_, __) =>
                Divider(color: AppColors.bord(context), height: 1),
            itemBuilder: (context, index) {
              final app = _recentApplications[index];
              final jobTitle =
                  (app['jobs'] as Map<String, dynamic>?)?['title'] ??
                  'Unknown job';

              // Extract applicant name from profiles list
              String applicantName = 'Anonymous';
              final profilesList = app['profiles'] as List?;
              if (profilesList != null && profilesList.isNotEmpty) {
                final profile = profilesList[0] as Map<String, dynamic>?;
                applicantName = profile?['full_name'] as String? ?? 'Anonymous';
              }

              final status = app['status'] as String? ?? 'applied';
              final createdAt = DateTime.tryParse(
                app['created_at'] as String? ?? '',
              );

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New application from $applicantName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$jobTitle • ${createdAt != null ? _formatDate(createdAt) : 'Recently'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSec(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'applied':
        return AppColors.primary;
      case 'interviewing':
        return Colors.orange;
      case 'offered':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'applied':
        return 'Applied';
      case 'interviewing':
        return 'Interviewing';
      case 'offered':
        return 'Offered';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}
