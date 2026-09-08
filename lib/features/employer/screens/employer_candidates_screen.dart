import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../messages/screens/chat_screen.dart';

class EmployerCandidatesScreen extends StatefulWidget {
  const EmployerCandidatesScreen({super.key});

  @override
  State<EmployerCandidatesScreen> createState() =>
      _EmployerCandidatesScreenState();
}

class _EmployerCandidatesScreenState extends State<EmployerCandidatesScreen> {
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  final _skillController = TextEditingController();
  List<Map<String, dynamic>> _candidates = [];
  final Set<String> _interestedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    setState(() => _loading = true);
    final recruiterId = Supabase.instance.client.auth.currentUser?.id;
    if (recruiterId == null) {
      setState(() {
        _candidates = [];
        _loading = false;
      });
      return;
    }

    final list = await SupabaseService.getOpenCandidates(
      searchQuery: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      skill: _skillController.text.trim().isEmpty
          ? null
          : _skillController.text.trim(),
    );

    final interested = <String>{};
    for (final c in list) {
      final id = c['id'] as String;
      if (await SupabaseService.hasExpressedInterestInCandidate(
        recruiterId,
        id,
      )) {
        interested.add(id);
      }
    }

    if (mounted) {
      setState(() {
        _candidates = list;
        _interestedIds
          ..clear()
          ..addAll(interested);
        _loading = false;
      });
    }
  }

  Future<void> _expressInterest(Map<String, dynamic> candidate) async {
    final recruiterId = Supabase.instance.client.auth.currentUser?.id;
    final candidateId = candidate['id'] as String? ?? '';
    if (recruiterId == null || candidateId.isEmpty) return;

    final messageController = TextEditingController(
      text:
          'Hi ${candidate['full_name']}, I came across your profile and would love to discuss an opportunity.',
    );

    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Express interest'),
        content: TextField(
          controller: messageController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Personal message to candidate',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, messageController.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (message == null) return;

    await SupabaseService.expressInterestInCandidate(
      recruiterId,
      candidateId,
      message: message.trim(),
    );

    setState(() => _interestedIds.add(candidateId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interest sent — candidate will be notified'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _messageCandidate(Map<String, dynamic> candidate) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: candidate['id'] as String,
          receiverName: candidate['full_name'] as String? ?? 'Candidate',
          receiverRole: candidate['job_title'] as String? ?? 'Candidate',
          receiverAvatarUrl: candidate['profile_photo_url'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Browse Candidates')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search candidates',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _loadCandidates(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _loadCandidates(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _skillController,
                        decoration: const InputDecoration(
                          labelText: 'Skill',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _loadCandidates(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadCandidates,
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _candidates.isEmpty
                ? Center(
                    child: Text(
                      'No open candidates match your filters',
                      style: TextStyle(color: AppColors.textSec(context)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCandidates,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _candidates.length,
                      itemBuilder: (context, index) {
                        final c = _candidates[index];
                        final id = c['id'] as String;
                        final interested = _interestedIds.contains(id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surf(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.bord(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    backgroundImage:
                                        c['profile_photo_url'] != null
                                        ? NetworkImage(
                                            c['profile_photo_url'] as String,
                                          )
                                        : null,
                                    child: c['profile_photo_url'] == null
                                        ? const Icon(
                                            Icons.person,
                                            color: AppColors.primary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['full_name'] as String? ??
                                              'Candidate',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text(context),
                                          ),
                                        ),
                                        Text(
                                          c['job_title'] as String? ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSec(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Open to work',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((c['location'] as String?)?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: AppColors.textSec(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      c['location'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSec(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if ((c['bio'] as String?)?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 8),
                                Text(
                                  c['bio'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSec(context),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: interested
                                          ? null
                                          : () => _expressInterest(c),
                                      icon: Icon(
                                        interested
                                            ? Icons.check
                                            : Icons.favorite_border,
                                      ),
                                      label: Text(
                                        interested
                                            ? 'Interested sent'
                                            : 'Express interest',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _messageCandidate(c),
                                    icon: const Icon(Icons.chat_outlined),
                                    tooltip: 'Message',
                                  ),
                                ],
                              ),
                            ],
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
