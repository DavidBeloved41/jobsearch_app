import '../supabase/supabase_service.dart';
import 'resume_text_service.dart';

class SkillGapItem {
  final String name;
  final String category;
  final int demandCount;
  final bool isMissing;

  const SkillGapItem({
    required this.name,
    required this.category,
    required this.demandCount,
    required this.isMissing,
  });
}

class SkillGapResult {
  final List<SkillGapItem> missingSkills;
  final List<SkillGapItem> matchedSkills;
  final int jobsAnalyzed;

  const SkillGapResult({
    required this.missingSkills,
    required this.matchedSkills,
    required this.jobsAnalyzed,
  });
}

class SkillGapService {
  static Future<SkillGapResult> analyze(
    String userId, {
    Map<String, dynamic>? targetJob,
  }) async {
    final userSkills = (await SupabaseService.getUserSkillNames(
      userId,
    )).map(_normalize).toSet();
    final profile = await SupabaseService.getProfile(userId);
    final resumeText = await ResumeTextService.fromProfile(profile);
    final candidateText = _normalize(
      [...userSkills, resumeText ?? ''].join(' '),
    );
    final jobs = targetJob == null
        ? await SupabaseService.getJobs()
        : [targetJob];
    final allSkills = await SupabaseService.getAllSkills();
    final categories = <String, String>{};
    for (final skill in allSkills) {
      final name = skill['name'] as String? ?? '';
      if (name.trim().isNotEmpty) {
        categories[_normalize(name)] =
            skill['category'] as String? ?? 'General';
      }
    }

    if (targetJob != null) {
      final missing = <SkillGapItem>[];
      final matched = <SkillGapItem>[];
      for (final name in _requiredSkills(targetJob, allSkills)) {
        final normalized = _normalize(name);
        final item = SkillGapItem(
          name: name,
          category: categories[normalized] ?? 'General',
          demandCount: 1,
          isMissing: !candidateText.contains(normalized),
        );
        (item.isMissing ? missing : matched).add(item);
      }
      return SkillGapResult(
        missingSkills: missing,
        matchedSkills: matched,
        jobsAnalyzed: 1,
      );
    }

    final demand = <String, int>{};
    for (final job in jobs) {
      final text = _normalize(
        [
          job['title'] as String? ?? '',
          job['description'] as String? ?? '',
          job['qualifications'] as String? ?? '',
          job['requirements'] as String? ?? '',
        ].join(' '),
      );
      for (final skill in allSkills) {
        final name = skill['name'] as String? ?? '';
        final normalized = _normalize(name);
        if (normalized.length >= 2 && text.contains(normalized)) {
          demand[normalized] = (demand[normalized] ?? 0) + 1;
        }
      }
    }

    final entries = demand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final missing = <SkillGapItem>[];
    final matched = <SkillGapItem>[];
    for (final entry in entries) {
      final displayName = allSkills
          .map((skill) => skill['name'] as String? ?? '')
          .firstWhere(
            (name) => _normalize(name) == entry.key,
            orElse: () => entry.key,
          );
      final item = SkillGapItem(
        name: displayName,
        category: categories[entry.key] ?? 'General',
        demandCount: entry.value,
        isMissing: !candidateText.contains(entry.key),
      );
      (item.isMissing ? missing : matched).add(item);
    }
    return SkillGapResult(
      missingSkills: missing.take(15).toList(),
      matchedSkills: matched.take(10).toList(),
      jobsAnalyzed: jobs.length,
    );
  }

  static List<String> _requiredSkills(
    Map<String, dynamic> job,
    List<Map<String, dynamic>> allSkills,
  ) {
    final raw = job['required_skills'] ?? job['skills'];
    if (raw is List) {
      return raw
          .map((value) => '$value'.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[,;\n|]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    final text = _normalize(
      [
        job['title'] as String? ?? '',
        job['description'] as String? ?? '',
        job['qualifications'] as String? ?? '',
        job['requirements'] as String? ?? '',
      ].join(' '),
    );
    return allSkills
        .map((skill) => skill['name'] as String? ?? '')
        .where(
          (name) => name.trim().isNotEmpty && text.contains(_normalize(name)),
        )
        .toList();
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('javascript', 'java script')
        .replaceAll(RegExp(r'[^a-z0-9+#]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
