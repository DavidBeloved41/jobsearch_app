import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../messages/screens/chat_screen.dart';

class ProfileVisibilityScreen extends StatefulWidget {
  const ProfileVisibilityScreen({super.key});

  @override
  State<ProfileVisibilityScreen> createState() =>
      _ProfileVisibilityScreenState();
}

class _ProfileVisibilityScreenState extends State<ProfileVisibilityScreen> {
  bool _loading = true;
  bool _isOpenToWork = false;
  String _visibility = 'everyone';
  List<Map<String, dynamic>> _inboundInterests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final profile = await SupabaseService.getProfile(userId);
    final interests = await SupabaseService.getInboundRecruiterInterests(
      userId,
    );

    if (mounted) {
      setState(() {
        _isOpenToWork = profile?['is_open_to_work'] ?? false;
        _visibility = profile?['profile_visibility'] as String? ?? 'everyone';
        _inboundInterests = interests;
        _loading = false;
      });
    }
  }

  void _openRecruiterChat(Map<String, dynamic> interest) {
    final recruiter = interest['recruiter'] as Map<String, dynamic>?;
    if (recruiter == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: recruiter['id'] as String,
          receiverName: recruiter['full_name'] as String? ?? 'Recruiter',
          receiverRole: recruiter['headline'] as String? ?? 'Recruiter',
          isRecruiter: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Profile Visibility')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surf(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.bord(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reverse search status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StatusRow(
                            icon: Icons.work_outline,
                            label: 'Open to work',
                            value: _isOpenToWork ? 'Visible' : 'Hidden',
                            active: _isOpenToWork,
                          ),
                          _StatusRow(
                            icon: Icons.visibility_outlined,
                            label: 'Profile visibility',
                            value: _visibility == 'everyone'
                                ? 'Employers can browse'
                                : 'Private',
                            active: _visibility == 'everyone',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When enabled, verified employers can discover your profile and send Express Interest invites.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSec(context),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Recruiter interest (${_inboundInterests.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_inboundInterests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surf(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.bord(context)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 48,
                              color: AppColors.textSec(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No recruiter interest yet',
                              style: TextStyle(
                                color: AppColors.textSec(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Keep your profile complete and "Open to work" enabled.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSec(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._inboundInterests.map((interest) {
                        final recruiter =
                            interest['recruiter'] as Map<String, dynamic>?;
                        final name =
                            recruiter?['full_name'] as String? ??
                            interest['title'] as String? ??
                            'Recruiter';
                        final company =
                            recruiter?['company_name'] as String? ?? '';
                        final headline =
                            recruiter?['headline'] as String? ?? 'Recruiter';
                        final message =
                            interest['message'] as String? ??
                            interest['body'] as String? ??
                            'Expressed interest in your profile';

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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Recruiter',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (interest['created_at'] != null)
                                    Text(
                                      DateFormatter.relative(
                                        interest['created_at'] as String,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSec(context),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text(context),
                                ),
                              ),
                              if (company.isNotEmpty)
                                Text(
                                  company,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSec(context),
                                  ),
                                ),
                              Text(
                                headline,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSec(context),
                                ),
                              ),
                              if (recruiter != null) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _openRecruiterChat(interest),
                                    icon: const Icon(
                                      Icons.chat_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Reply'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool active;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? AppColors.success : AppColors.textSec(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.text(context)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: active ? AppColors.success : AppColors.textSec(context),
            ),
          ),
        ],
      ),
    );
  }
}
