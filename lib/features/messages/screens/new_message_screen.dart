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
      final results = await SupabaseService.searchProfiles(trimmed);
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
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: AppColors.text(context)),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: TextStyle(color: AppColors.textSec(context)),
                prefixIcon: Icon(Icons.search, color: AppColors.textSec(context)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          'Type at least 2 characters to search',
                          style: TextStyle(color: AppColors.textSec(context)),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              'No users found',
                              style: TextStyle(color: AppColors.textSec(context)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final profile = _results[index];
                              final id = profile['id'] as String? ?? '';
                              if (id == currentUserId) return const SizedBox.shrink();

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  profile['full_name'] as String? ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                subtitle: Text(
                                  profile['headline'] as String? ?? '',
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
