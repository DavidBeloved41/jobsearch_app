import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import 'chat_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String? _error;
  bool _recruitersOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = _recruitersOnly
          ? await SupabaseService.searchRecruiters(trimmed)
          : await SupabaseService.searchProfiles(trimmed);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not search users. Please try again.';
        });
      }
    }
  }

  void _openChat(Map<String, dynamic> profile) {
    final id = profile['id'] as String? ?? '';
    final name = profile['full_name'] as String? ?? 'Unknown';
    final role = profile['headline'] as String? ?? '';
    if (id.isEmpty) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: id,
          receiverName: name,
          receiverRole: role,
          isRecruiter: SupabaseService.isRecruiterProfile(profile),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('New message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Everyone')),
                ButtonSegment(value: true, label: Text('Recruiters')),
              ],
              selected: {_recruitersOnly},
              onSelectionChanged: (s) {
                setState(() => _recruitersOnly = s.first);
                if (_searchController.text.trim().length >= 2) {
                  _search(_searchController.text);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: AppColors.text(context)),
              decoration: InputDecoration(
                hintText: _recruitersOnly
                    ? 'Search recruiters by name...'
                    : 'Search by name...',
                hintStyle: TextStyle(color: AppColors.textSec(context)),
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textSec(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.bord(context)),
                ),
              ),
              onChanged: _search,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _searchController.text.trim().length < 2
                    ? Center(
                        child: Text(
                          _recruitersOnly
                              ? 'Find verified recruiters to ask about roles'
                              : 'Type at least 2 characters to search',
                          style: TextStyle(color: AppColors.textSec(context)),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              'No users found',
                              style:
                                  TextStyle(color: AppColors.textSec(context)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final profile = _results[index];
                              final id = profile['id'] as String? ?? '';
                              if (id == currentUserId) {
                                return const SizedBox.shrink();
                              }

                              final isRecruiter =
                                  SupabaseService.isRecruiterProfile(profile);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  child: Icon(
                                    isRecruiter
                                        ? Icons.badge_outlined
                                        : Icons.person,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        profile['full_name'] as String? ??
                                            'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.text(context),
                                        ),
                                      ),
                                    ),
                                    if (isRecruiter)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Recruiter',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  [
                                    profile['headline'] as String? ?? '',
                                    profile['company_name'] as String? ?? '',
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: TextStyle(
                                    color: AppColors.textSec(context),
                                  ),
                                ),
                                onTap: () => _openChat(profile),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
