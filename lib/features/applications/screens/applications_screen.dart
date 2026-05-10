import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final applications = await SupabaseService.getApplications(userId);
      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading applications: $e');
    }
  }

  List<Map<String, dynamic>> _filterByStatus(String status) {
    return _applications.where((app) => app['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final applied = _filterByStatus('applied');
    final interviewing = _filterByStatus('interviewing');
    final offered = _filterByStatus('offered');
    final declined = _filterByStatus('declined');

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Applications'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSec(context),
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Applied (${applied.length})'),
            Tab(text: 'Interviewing (${interviewing.length})'),
            Tab(text: 'Offered (${offered.length})'),
            Tab(text: 'Declined (${declined.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(applied, AppColors.primary),
                _buildList(interviewing, AppColors.warning),
                _buildList(offered, AppColors.success),
                _buildList(declined, AppColors.error),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, Color color) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: AppColors.textSec(context)),
            const SizedBox(height: 16),
            Text(
              'No applications here yet',
              style: TextStyle(color: AppColors.textSec(context)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final job = item['jobs'] as Map<String, dynamic>?;
          final company = job?['companies'] as Map<String, dynamic>?;
          final appliedAt = DateTime.parse(item['applied_at']);
          final formattedDate =
              '${appliedAt.day} ${_monthName(appliedAt.month)} ${appliedAt.year}';

          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(width: 4, color: color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.business,
                                  color: color, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                ],
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSec(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}