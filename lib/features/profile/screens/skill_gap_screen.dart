import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/skill_gap_service.dart';
import '../../../core/theme/app_colors.dart';
import 'skills_screen.dart';

class SkillGapScreen extends StatefulWidget {
  const SkillGapScreen({super.key});

  @override
  State<SkillGapScreen> createState() => _SkillGapScreenState();
}

class _SkillGapScreenState extends State<SkillGapScreen> {
  SkillGapResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sign in to analyze your skill gaps';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await SkillGapService.analyze(userId);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not analyze skills. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Skill gap analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _analyze,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSec(context)),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _analyze,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insights_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Analyzed ${_result!.jobsAnalyzed} active jobs against your profile skills.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.text(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Skills to add',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'In high demand for roles you\'re browsing',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSec(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_result!.missingSkills.isEmpty)
                        _emptyCard(
                          context,
                          'Great job! Your skills align well with current openings.',
                          Icons.check_circle_outline,
                          AppColors.success,
                        )
                      else
                        ..._result!.missingSkills.map(
                          (s) => _skillTile(context, s, isMissing: true),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Your matching skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_result!.matchedSkills.isEmpty)
                        _emptyCard(
                          context,
                          'Add skills to your profile to see matches here.',
                          Icons.school_outlined,
                          AppColors.warning,
                        )
                      else
                        ..._result!.matchedSkills.map(
                          (s) => _skillTile(context, s, isMissing: false),
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SkillsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Manage my skills'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyCard(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.textSec(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillTile(
    BuildContext context,
    SkillGapItem skill, {
    required bool isMissing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.warning_amber_rounded : Icons.check_circle,
            color: isMissing ? AppColors.warning : AppColors.success,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                Text(
                  skill.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSec(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${skill.demandCount} jobs',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
