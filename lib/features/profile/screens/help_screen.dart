import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How does the job match score work?',
      'answer':
          'The match score is calculated by comparing your skills, experience level and job preferences against the job requirements. A higher score means you are a stronger fit for the role.',
    },
    {
      'question': 'How do I improve my match score?',
      'answer':
          'Add more skills to your profile, keep your experience level up to date, and complete your profile fully. The more information you provide, the better your matches will be.',
    },
    {
      'question': 'Can employers see my profile?',
      'answer':
          'Only verified employers can browse candidate profiles, and only if you have "Open to work" enabled on your profile. You can turn this off anytime in your profile settings.',
    },
    {
      'question': 'How do I track my applications?',
      'answer':
          'Go to the Applications tab at the bottom of the screen. Your applications are organized into four stages: Applied, Interviewing, Offered, and Declined.',
    },
    {
      'question': 'How do I upload my resume?',
      'answer':
          'Go to Profile → My Resume and tap "Upload Resume". We support PDF, DOC, and DOCX formats up to 5MB in size.',
    },
    {
      'question': 'How do I delete my account?',
      'answer':
          'To delete your account please contact our support team at support@jobsearch.app. Note that this action is permanent and cannot be undone.',
    },
    {
      'question': 'Is my data secure?',
      'answer':
          'Yes. We use industry standard encryption and Row Level Security to protect your data. We never sell your personal information to third parties.',
    },
  ];

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact support card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent,
                      color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Need help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team is available Monday to Friday, 9am - 6pm GMT.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // FAQ section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // FAQ items
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _faqs.length,
                separatorBuilder: (context, index) =>
                    Divider(color: AppColors.border, height: 1),
                itemBuilder: (context, index) {
                  final faq = _faqs[index];
                  final isExpanded = _expandedIndex == index;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _expandedIndex = isExpanded ? null : index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  faq['question']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isExpanded
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isExpanded
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: isExpanded
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 12),
                            Text(
                              faq['answer']!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Quick links
            const Text(
              'Quick Links',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _QuickLink(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () {},
                  ),
                  Divider(color: AppColors.border, height: 1),
                  _QuickLink(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                    onTap: () {},
                  ),
                  Divider(color: AppColors.border, height: 1),
                  _QuickLink(
                    icon: Icons.star_outline,
                    label: 'Rate the App',
                    onTap: () {},
                  ),
                  Divider(color: AppColors.border, height: 1),
                  _QuickLink(
                    icon: Icons.share_outlined,
                    label: 'Share with Friends',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App version
            Center(
              child: Text(
                'JobSearch App v1.0.0',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}