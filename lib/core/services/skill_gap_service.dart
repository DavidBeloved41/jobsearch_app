import '../supabase/supabase_service.dart';

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
  static Future<SkillGapResult> analyze(String userId) async {
    final userSkillNames = (await SupabaseService.getUserSkillNames(userId))
        .map((s) => s.toLowerCase())
        .toSet();

    final jobs = await SupabaseService.getJobs();
    final allSkills = await SupabaseService.getAllSkills();

    final demand = <String, int>{};
    final categories = <String, String>{};

    for (final skill in allSkills) {
      final name = (skill['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      categories[name.toLowerCase()] =
          skill['category'] as String? ?? 'General';
    }

    for (final job in jobs) {
      final text = [
        job['title'] as String? ?? '',
        job['description'] as String? ?? '',
      ].join(' ').toLowerCase();

      for (final skill in allSkills) {
        final name = (skill['name'] as String? ?? '').trim();
        if (name.length < 2) continue;
        if (text.contains(name.toLowerCase())) {
          final key = name.toLowerCase();
          demand[key] = (demand[key] ?? 0) + 1;
        }
      }
    }

    final sortedDemand = demand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final missing = <SkillGapItem>[];
    final matched = <SkillGapItem>[];

    for (final entry in sortedDemand) {
      if (entry.value < 1) continue;
      final displayName = allSkills
          .map((s) => s['name'] as String? ?? '')
          .firstWhere(
            (n) => n.toLowerCase() == entry.key,
            orElse: () => entry.key,
          );
      final item = SkillGapItem(
        name: displayName,
        category: categories[entry.key] ?? 'General',
        demandCount: entry.value,
        isMissing: !userSkillNames.contains(entry.key),
      );
      if (item.isMissing) {
        missing.add(item);
      } else {
        matched.add(item);
      }
    }

    return SkillGapResult(
      missingSkills: missing.take(15).toList(),
      matchedSkills: matched.take(10).toList(),
      jobsAnalyzed: jobs.length,
    );
  }
}
