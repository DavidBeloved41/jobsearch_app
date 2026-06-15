import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/company_logo.dart';
import '../../jobs/screens/job_detail_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  bool _isOffline = false;

  static const _columns = [
    _KanbanColumn(id: 'applied', label: 'Applied', color: AppColors.primary),
    _KanbanColumn(
      id: 'interviewing',
      label: 'Interviewing',
      color: AppColors.warning,
    ),
    _KanbanColumn(id: 'offered', label: 'Offered', color: AppColors.success),
    _KanbanColumn(id: 'declined', label: 'Declined', color: AppColors.error),
  ];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _applications = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final online = await Connectivity().checkConnectivity();
      final hasNetwork = !online.contains(ConnectivityResult.none);

      if (hasNetwork) {
        final applications = await SupabaseService.getApplications(userId);
        await OfflineCacheService.cacheApplications(userId, applications);
        setState(() {
          _applications = applications;
          _isOffline = false;
          _isLoading = false;
        });
      } else {
        throw Exception('offline');
      }
    } catch (e) {
      final cached = await OfflineCacheService.getCachedApplications(userId);
      setState(() {
        _applications = cached ?? [];
        _isOffline = cached != null;
        _isLoading = false;
      });
      if (cached == null) {
        debugPrint('Error loading applications: $e');
      }
    }
  }

  List<Map<String, dynamic>> _forStatus(String status) {
    return _applications.where((a) => a['status'] == status).toList();
  }

  Future<void> _openJobDetail(Map<String, dynamic> item) async {
    final jobId = item['job_id'] as String?;
    if (jobId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final job = await SupabaseService.getJobById(jobId);
      if (!mounted) return;
      Navigator.pop(context);

      if (job != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        );
        _loadApplications();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load job details'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _moveApplication(
    Map<String, dynamic> item,
    String newStatus,
  ) async {
    final id = item['id'] as String?;
    if (id == null) return;

    try {
      await SupabaseService.updateApplicationStatus(id, newStatus);
      setState(() {
        item['status'] = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to ${_labelFor(newStatus)}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _labelFor(String status) {
    return _columns.firstWhere((c) => c.id == status).label;
  }

  void _showMoveMenu(Map<String, dynamic> item) {
    final current = item['status'] as String? ?? 'applied';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Move application',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
            ),
            ..._columns.where((c) => c.id != current).map(
                  (col) => ListTile(
                    leading: Icon(Icons.circle, size: 12, color: col.color),
                    title: Text(col.label),
                    onTap: () {
                      Navigator.pop(context);
                      _moveApplication(item, col.id);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Application tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: userId == null
          ? Center(
              child: Text(
                'Sign in to track your applications',
                style: TextStyle(color: AppColors.textSec(context)),
              ),
            )
          : _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : RefreshIndicator(
                  onRefresh: _loadApplications,
                  child: Column(
                    children: [
                      if (_isOffline)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Offline — showing cached applications',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.72,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(12),
                          children: _columns.map((col) {
                            final items = _forStatus(col.id);
                            return _KanbanBoardColumn(
                              column: col,
                              items: items,
                              onTapCard: _openJobDetail,
                              onMoveCard: _showMoveMenu,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _KanbanColumn {
  final String id;
  final String label;
  final Color color;

  const _KanbanColumn({
    required this.id,
    required this.label,
    required this.color,
  });
}

class _KanbanBoardColumn extends StatelessWidget {
  final _KanbanColumn column;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onTapCard;
  final void Function(Map<String, dynamic>) onMoveCard;

  const _KanbanBoardColumn({
    required this.column,
    required this.items,
    required this.onTapCard,
    required this.onMoveCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: column.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: column.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  column.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: column.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: column.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No items',
                        style: TextStyle(
                          color: AppColors.textSec(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final job = item['jobs'] as Map<String, dynamic>?;
                      final company =
                          job?['companies'] as Map<String, dynamic>?;

                      return GestureDetector(
                        onTap: () => onTapCard(item),
                        onLongPress: () => onMoveCard(item),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.bord(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CompanyLogo(
                                    logoUrl:
                                        company?['logo_url'] as String?,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      job?['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text(context),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.more_horiz,
                                      size: 18,
                                      color: AppColors.textSec(context),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => onMoveCard(item),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                company?['name'] ?? '',
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
