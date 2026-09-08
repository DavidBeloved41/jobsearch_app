import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../widgets/admin_navigation_drawer.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = true;
  String? _error;
  String _filterRole = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _roles = ['all', 'job_seeker', 'employer', 'admin'];

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
    _loadProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await SupabaseService.getAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
        debugPrint('Error loading profiles: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProfiles {
    return _profiles.where((profile) {
      final roleMatches =
          _filterRole == 'all' || profile['account_type'] == _filterRole;
      final haystack = '${profile['full_name'] ?? ''} ${profile['id'] ?? ''}'
          .toLowerCase();
      return roleMatches &&
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
          title: const Text('User Management'),
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
          selectedRoute: AppRoutes.adminUsers,
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
                      hintText: 'Search users by name or ID',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _roles.map((role) {
                        final isSelected = _filterRole == role;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              role == 'all' ? 'All Users' : role.toUpperCase(),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _filterRole = role);
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
                            'Error loading users',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We could not load users. Check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSec(context),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadProfiles,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProfiles.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.people_outline,
                      title: 'No users found',
                      message: 'Registered SmartJob accounts will appear here.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredProfiles.length,
                      itemBuilder: (context, index) {
                        final profile = _filteredProfiles[index];
                        final createdAtRaw = profile['created_at'];
                        final createdAt = createdAtRaw is String
                            ? DateTime.tryParse(createdAtRaw)?.toLocal()
                            : null;
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
                              backgroundColor: _getRoleColor(
                                profile['account_type'],
                              ).withValues(alpha: 0.12),
                              foregroundColor: _getRoleColor(
                                profile['account_type'],
                              ),
                              child: const Icon(Icons.person_outline),
                            ),
                            title: Text(
                              profile['full_name'] ?? 'No Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(profile['email'] ?? 'No Email'),
                                Text(
                                  'Role: ${_roleLabel(profile['account_type'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getRoleColor(
                                      profile['account_type'],
                                    ),
                                  ),
                                ),
                                Text(
                                  'Joined: ${createdAt == null ? 'Unknown date' : createdAt.toString().split('.')[0]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSec(context),
                                  ),
                                ),
                              ],
                            ),
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

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'job_seeker':
        return Colors.blue;
      case 'employer':
        return Colors.green;
      case 'admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(Object? role) {
    switch (role?.toString()) {
      case 'admin':
        return 'Admin';
      case 'employer':
        return 'Employer';
      case 'job_seeker':
        return 'Job Seeker';
      default:
        return 'Unknown';
    }
  }
}
