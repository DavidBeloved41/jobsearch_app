import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/utils/external_url_policy.dart';
import '../../messages/screens/chat_screen.dart';

class EmployerApplicationsScreen extends StatefulWidget {
  const EmployerApplicationsScreen({super.key});

  @override
  State<EmployerApplicationsScreen> createState() =>
      _EmployerApplicationsScreenState();
}

class _EmployerApplicationsScreenState
    extends State<EmployerApplicationsScreen> {
  final _statuses = const [
    'all',
    'applied',
    'interviewing',
    'offered',
    'declined',
  ];
  String _selectedStatus = 'all';
  List<Map<String, dynamic>> _applications = [];
  bool _loading = true;
  String? _error;
  String? _updatingId;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    final employerId = Supabase.instance.client.auth.currentUser?.id;
    if (employerId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in again.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final applications = await SupabaseService.getApplicationsForEmployer(
        employerId,
      );
      if (mounted) {
        setState(() {
          _applications = applications;
          _loading = false;
        });
      }
    } catch (error) {
      debugPrint('Employer applications load failed: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load applications. Please try again.';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visibleApplications {
    if (_selectedStatus == 'all') return _applications;
    return _applications
        .where((application) => application['status'] == _selectedStatus)
        .toList();
  }

  void _openApplicant(Map<String, dynamic> application) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                EmployerApplicantReviewScreen(application: application),
          ),
        )
        .then((_) => _loadApplications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Applications'),
        backgroundColor: AppColors.surf(context),
        actions: [
          IconButton(
            onPressed: _loadApplications,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh applications',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final status = _statuses[index];
                return FilterChip(
                  label: Text(_label(status)),
                  selected: _selectedStatus == status,
                  onSelected: (_) => setState(() => _selectedStatus = status),
                );
              },
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: AppColors.textSec(context))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadApplications,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_visibleApplications.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline,
        title: _selectedStatus == 'all'
            ? 'No applications yet'
            : 'No ${_label(_selectedStatus).toLowerCase()} applications',
        message: 'Applications for your approved jobs will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _visibleApplications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) =>
            _applicationCard(context, _visibleApplications[index]),
      ),
    );
  }

  Widget _applicationCard(
    BuildContext context,
    Map<String, dynamic> application,
  ) {
    final applicant = _asMap(application['profiles']);
    final job = _asMap(application['jobs']);
    final status = application['status']?.toString() ?? 'applied';
    final applicantName = applicant?['full_name']?.toString().trim();
    final jobTitle = job?['title']?.toString() ?? 'Unknown job';
    final id = application['id']?.toString();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundImage: _imageProvider(applicant?['profile_photo_url']),
          child: _imageProvider(applicant?['profile_photo_url']) == null
              ? const Icon(Icons.person_outline)
              : null,
        ),
        title: Text(
          (applicantName == null || applicantName.isEmpty)
              ? 'Applicant'
              : applicantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$jobTitle\n${applicant?['job_title'] ?? 'Job seeker'}\nApplied: ${_formatDate(application['applied_at'])}',
          ),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(_label(status), style: const TextStyle(fontSize: 11)),
              backgroundColor: _statusColor(status).withValues(alpha: 0.15),
            ),
            if (_updatingId == id)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        onTap: () => _openApplicant(application),
      ),
    );
  }

  String _label(String status) => status == 'all'
      ? 'All'
      : '${status[0].toUpperCase()}${status.substring(1)}';
  Color _statusColor(String status) => switch (status) {
    'interviewing' => AppColors.warning,
    'offered' => AppColors.success,
    'declined' => AppColors.error,
    _ => AppColors.primary,
  };
  String _formatDate(dynamic value) =>
      DateTime.tryParse(
        value?.toString() ?? '',
      )?.toLocal().toString().split('.').first ??
      'Unknown date';
  Map<String, dynamic>? _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : value is List && value.isNotEmpty && value.first is Map
      ? Map<String, dynamic>.from(value.first as Map)
      : null;
  ImageProvider<Object>? _imageProvider(dynamic value) {
    final url = value?.toString();
    return url == null || url.isEmpty ? null : NetworkImage(url);
  }
}

class EmployerApplicantReviewScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  const EmployerApplicantReviewScreen({super.key, required this.application});
  @override
  State<EmployerApplicantReviewScreen> createState() =>
      _EmployerApplicantReviewScreenState();
}

class _EmployerApplicantReviewScreenState
    extends State<EmployerApplicantReviewScreen> {
  bool _updating = false;
  Map<String, dynamic>? get _applicant =>
      _asMap(widget.application['profiles']);
  Map<String, dynamic>? get _job => _asMap(widget.application['jobs']);

  Future<void> _setStatus(String status) async {
    final employerId = Supabase.instance.client.auth.currentUser?.id;
    final id = widget.application['id']?.toString();
    if (employerId == null || id == null) return;
    setState(() => _updating = true);
    try {
      final persisted = await SupabaseService.updateApplicationStatus(
        id,
        status,
        employerId: employerId,
      );
      if (mounted) {
        setState(() {
          widget.application['status'] = persisted['status'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Application moved to ${_label(status)}')),
        );
      }
    } catch (error) {
      debugPrint(
        'Applicant status update failed: ${SupabaseService.describeSupabaseError(error)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update application status'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _confirmDecline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline application?'),
        content: const Text(
          'The application will remain in your records with Declined status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _setStatus('declined');
  }

  void _messageCandidate() {
    final applicant = _applicant;
    final id = applicant?['id']?.toString();
    if (id == null || id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: id,
          receiverName: applicant?['full_name']?.toString() ?? 'Candidate',
          receiverRole: applicant?['job_title']?.toString() ?? 'Job seeker',
          receiverAvatarUrl: applicant?['profile_photo_url']?.toString(),
        ),
      ),
    );
  }

  Future<void> _openResume() async {
    final url = _applicant?['resume_url']?.toString();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !ExternalUrlPolicy.isAllowedResumeUri(uri) ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open resume')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicant = _applicant;
    final job = _job;
    final name = applicant?['full_name']?.toString().trim();
    final resumeUrl = applicant?['resume_url']?.toString();
    final status = widget.application['status']?.toString() ?? 'applied';
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Applicant review'),
        backgroundColor: AppColors.surf(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundImage: _imageProvider(
                      applicant?['profile_photo_url'],
                    ),
                    child:
                        _imageProvider(applicant?['profile_photo_url']) == null
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (name == null || name.isEmpty) ? 'Applicant' : name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${applicant?['job_title'] ?? 'Job seeker'}',
                    style: TextStyle(color: AppColors.textSec(context)),
                  ),
                  if (applicant?['location'] != null)
                    Text(
                      '${applicant!['location']}',
                      style: TextStyle(color: AppColors.textSec(context)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section(context, 'Application', [
            _row('Job', job?['title'] ?? 'Unknown job'),
            _row('Applied', _formatDate(widget.application['applied_at'])),
            _row('Status', _label(status)),
            _row(
              'Match score',
              widget.application['match_score']?.toString() ?? 'Not available',
            ),
          ]),
          if (applicant?['bio'] != null)
            _section(context, 'About', [Text('${applicant!['bio']}')]),
          _section(context, 'Resume', [
            if (resumeUrl != null && resumeUrl.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _openResume,
                icon: const Icon(Icons.description_outlined),
                label: const Text('View resume'),
              )
            else
              const Text('No resume reference available.'),
          ]),
          if (widget.application['cover_letter'] != null &&
              '${widget.application['cover_letter']}'.trim().isNotEmpty)
            _section(context, 'Cover letter', [
              Text('${widget.application['cover_letter']}'),
            ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status != 'interviewing')
                ElevatedButton.icon(
                  onPressed: _updating
                      ? null
                      : () => _setStatus('interviewing'),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Move to interview'),
                ),
              if (status != 'offered')
                OutlinedButton.icon(
                  onPressed: _updating ? null : () => _setStatus('offered'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Offer'),
                ),
              if (status != 'declined')
                OutlinedButton.icon(
                  onPressed: _updating ? null : _confirmDecline,
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                ),
              OutlinedButton.icon(
                onPressed: _messageCandidate,
                icon: const Icon(Icons.message_outlined),
                label: const Text('Message candidate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
  Widget _row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text('$value')),
      ],
    ),
  );
  String _label(String status) =>
      '${status[0].toUpperCase()}${status.substring(1)}';
  String _formatDate(dynamic value) =>
      DateTime.tryParse(
        value?.toString() ?? '',
      )?.toLocal().toString().split('.').first ??
      'Unknown date';
  Map<String, dynamic>? _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : value is List && value.isNotEmpty && value.first is Map
      ? Map<String, dynamic>.from(value.first as Map)
      : null;
  ImageProvider<Object>? _imageProvider(dynamic value) {
    final url = value?.toString();
    return url == null || url.isEmpty ? null : NetworkImage(url);
  }
}
