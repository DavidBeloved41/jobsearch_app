import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<Map<String, dynamic>> _userSkills = [];
  List<Map<String, dynamic>> _allSkills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Load all available skills
      final allSkills = await Supabase.instance.client
          .from('skills')
          .select()
          .order('name');

      // Load user's skills
      final userSkills = await Supabase.instance.client
          .from('profile_skills')
          .select('*, skills(name, category)')
          .eq('user_id', userId);

      setState(() {
        _allSkills = List<Map<String, dynamic>>.from(allSkills);
        _userSkills = List<Map<String, dynamic>>.from(userSkills);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading skills: $e');
    }
  }

  Future<void> _addSkill(Map<String, dynamic> skill, String proficiency) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profile_skills').insert({
        'user_id': userId,
        'skill_id': skill['id'],
        'proficiency_level': proficiency,
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${skill['name']} added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skill already added or error occurred'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteSkill(String profileSkillId, String skillName) async {
    try {
      await Supabase.instance.client
          .from('profile_skills')
          .delete()
          .eq('id', profileSkillId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$skillName removed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting skill: $e');
    }
  }

  void _showAddSkillDialog() {
    String? selectedSkillId;
    String selectedProficiency = 'intermediate';

    // Filter out skills already added
    final addedSkillIds = _userSkills
        .map((s) => s['skill_id'] as String)
        .toSet();
    final availableSkills = _allSkills
        .where((s) => !addedSkillIds.contains(s['id']))
        .toList();

    if (availableSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available skills have been added'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Skill',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Skill dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select skill',
                      prefixIcon: Icon(Icons.code_outlined),
                    ),
                    items: availableSkills.map((skill) {
                      return DropdownMenuItem<String>(
                        value: skill['id'] as String,
                        child: Text(skill['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() => selectedSkillId = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Proficiency level
                  const Text(
                    'Proficiency level',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['beginner', 'intermediate', 'advanced', 'expert']
                        .map((level) {
                      final isSelected = selectedProficiency == level;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedProficiency = level),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            level[0].toUpperCase() + level.substring(1),
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: selectedSkillId == null
                        ? null
                        : () {
                            final skill = availableSkills.firstWhere(
                                (s) => s['id'] == selectedSkillId);
                            Navigator.pop(context);
                            _addSkill(skill, selectedProficiency);
                          },
                    child: const Text('Add Skill'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getProficiencyColor(String? level) {
    switch (level) {
      case 'beginner':
        return AppColors.warning;
      case 'intermediate':
        return AppColors.primary;
      case 'advanced':
        return AppColors.success;
      case 'expert':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Skills & Experience'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddSkillDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _userSkills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology_outlined,
                          size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      const Text(
                        'No skills added yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your skills to improve job matches',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddSkillDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Skill'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userSkills.length,
                  itemBuilder: (context, index) {
                    final item = _userSkills[index];
                    final skill = item['skills'] as Map<String, dynamic>?;
                    final proficiency = item['proficiency_level'] as String?;
                    final color = _getProficiencyColor(proficiency);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.code, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  skill?['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        proficiency != null
                                            ? proficiency[0].toUpperCase() +
                                                proficiency.substring(1)
                                            : '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: color,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      skill?['category'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error, size: 20),
                            onPressed: () => _deleteSkill(
                              item['id'] as String,
                              skill?['name'] ?? '',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}