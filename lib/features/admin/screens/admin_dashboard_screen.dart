import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  int _users = 0;
  int _jobs = 0;
  int _applications = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id');
      final jobs = await Supabase.instance.client.from('jobs').select('id');
      final applications = await Supabase.instance.client
          .from('applications')
          .select('id');

      if (mounted) {
        setState(() {
          _users = (profiles as List).length;
          _jobs = (jobs as List).length;
          _applications = (applications as List).length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Admin dashboard load error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.surf(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricCard(label: 'Users', value: '$_users'),
                        _MetricCard(label: 'Jobs', value: '$_jobs'),
                        _MetricCard(
                          label: 'Applications',
                          value: '$_applications',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.people_outline),
                        title: Text('Users'),
                        subtitle: Text(
                          'Manage account activity and approvals',
                        ),
                      ),
                    ),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.work_outline),
                        title: Text('Jobs'),
                        subtitle: Text('Review and manage job posts'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
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
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
