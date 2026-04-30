import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  final List<Map<String, dynamic>> _conversations = const [
    {
      'name': 'Sarah Johnson',
      'role': 'Recruiter at Google',
      'message': 'Hi David, we reviewed your application...',
      'time': '10:30 AM',
      'unread': 2,
      'avatar': Icons.person,
    },
    {
      'name': 'Michael Chen',
      'role': 'HR Manager at Spotify',
      'message': 'Would you be available for an interview?',
      'time': 'Yesterday',
      'unread': 1,
      'avatar': Icons.person,
    },
    {
      'name': 'Emily Roberts',
      'role': 'Talent Acquisition at Meta',
      'message': 'Thank you for your interest in the role.',
      'time': 'Apr 20',
      'unread': 0,
      'avatar': Icons.person,
    },
    {
      'name': 'James Wilson',
      'role': 'CTO at Airbnb',
      'message': 'We would like to extend an offer...',
      'time': 'Apr 18',
      'unread': 0,
      'avatar': Icons.person,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final chat = _conversations[index];
          final bool hasUnread = chat['unread'] > 0;

          return InkWell(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: hasUnread
                    ? AppColors.primary.withValues(alpha: 0.03)
                    : AppColors.surface,
                border: const Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          chat['avatar'],
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      // Online indicator
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Message content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              chat['name'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              chat['time'],
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnread
                                    ? AppColors.primary
                                    : AppColors.textHint,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chat['role'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                chat['message'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hasUnread
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: hasUnread
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  chat['unread'].toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}