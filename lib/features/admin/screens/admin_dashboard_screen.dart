import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/admin_navigation_drawer.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;
  int _users = 0;
  int _totalJobs = 0;
  int _pendingJobs = 0;
  int _approvedJobs = 0;
  int _rejectedJobs = 0;
  int _applications = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugPrint('[ADMIN DASHBOARD] Loading statistics...');
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id');

      final allJobs = await Supabase.instance.client
          .from('jobs')
          .select('id, approval_status');

      final applications = await Supabase.instance.client
          .from('applications')
          .select('id');

      final jobsList = allJobs as List;
      debugPrint(
        '[ADMIN DASHBOARD] Total jobs in database: ${jobsList.length}',
      );
      for (final job in jobsList) {
        debugPrint(
          '[ADMIN DASHBOARD]   - Job: ${job['id']} (status=${job['approval_status']})',
        );
      }

      final pendingJobs = jobsList
          .where((j) => j['approval_status'] == 'pending')
          .length;
      final approvedJobs = jobsList
          .where((j) => j['approval_status'] == 'approved')
          .length;
      final rejectedJobs = jobsList
          .where((j) => j['approval_status'] == 'rejected')
          .length;

      debugPrint(
        '[ADMIN DASHBOARD] Pending=$pendingJobs, Approved=$approvedJobs, Rejected=$rejectedJobs',
      );

      if (mounted) {
        setState(() {
          _users = (profiles as List).length;
          _totalJobs = jobsList.length;
          _pendingJobs = pendingJobs;
          _approvedJobs = approvedJobs;
          _rejectedJobs = rejectedJobs;
          _applications = (applications as List).length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
        debugPrint('[ADMIN DASHBOARD] Error loading stats: $e');
      }
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
          title: const Text('Admin Dashboard'),
          backgroundColor: AppColors.surf(context),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Navigate admin menu',
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadStats,
              tooltip: 'Refresh statistics',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
              tooltip: 'Logout',
            ),
          ],
        ),
        drawer: const AdminNavigationDrawer(
          selectedRoute: AppRoutes.adminDashboard,
        ),
        body: _error != null && !_loading
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
                      'Error loading dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We could not load the dashboard. Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSec(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadStats,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Overview',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 560
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 12) /
                              columns;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricCard(
                                label: 'Total Users',
                                value: '$_users',
                                icon: Icons.people_outline,
                                width: width,
                              ),
                              _MetricCard(
                                label: 'Total Jobs',
                                value: '$_totalJobs',
                                icon: Icons.work_outline,
                                width: width,
                              ),
                              _MetricCard(
                                label: 'Applications',
                                value: '$_applications',
                                icon: Icons.assignment_outlined,
                                width: width,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Job Approvals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ApprovalCard(
                            label: 'Pending',
                            value: '$_pendingJobs',
                            color: Colors.orange,
                          ),
                          _ApprovalCard(
                            label: 'Approved',
                            value: '$_approvedJobs',
                            color: Colors.green,
                          ),
                          _ApprovalCard(
                            label: 'Rejected',
                            value: '$_rejectedJobs',
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ManagementCard(
                        icon: Icons.work_outline,
                        title: 'Job Postings',
                        subtitle: 'Review and manage job posts',
                        onTap: () => context.go(AppRoutes.adminJobs),
                      ),
                      _ManagementCard(
                        icon: Icons.people_outline,
                        title: 'Users',
                        subtitle: 'View and manage user accounts',
                        onTap: () => context.go(AppRoutes.adminUsers),
                      ),
                      _ManagementCard(
                        icon: Icons.assignment_outlined,
                        title: 'Applications',
                        subtitle: 'Track and review job applications',
                        onTap: () => context.go(AppRoutes.adminApplications),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double width;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.bord(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                foregroundColor: AppColors.primary,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: AppColors.textSec(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ApprovalCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSec(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}
