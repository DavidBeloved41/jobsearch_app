class MatchScoreService {
  static const _experienceLevels = ['entry', 'mid', 'senior', 'lead', 'executive'];

  static int calculate({
    required Map<String, dynamic> job,
    required List<String> userSkillNames,
    int? userYearsExperience,
  }) {
    var score = 35.0;

    final jobText = [
      job['title'] as String? ?? '',
      job['description'] as String? ?? '',
    ].join(' ').toLowerCase();

    if (userSkillNames.isNotEmpty && jobText.isNotEmpty) {
      final matched = userSkillNames.where((skill) {
        final name = skill.trim().toLowerCase();
        return name.length >= 2 && jobText.contains(name);
      }).length;
      final skillRatio = matched / userSkillNames.length;
      score += skillRatio * 45;
    } else if (userSkillNames.isEmpty) {
      score += 10;
    }

    final jobLevel = (job['experience_level'] as String? ?? '').toLowerCase();
    if (jobLevel.isNotEmpty && userYearsExperience != null) {
      final userLevel = _levelFromYears(userYearsExperience);
      final jobIndex = _experienceLevels.indexOf(jobLevel);
      final userIndex = _experienceLevels.indexOf(userLevel);
      if (jobIndex >= 0 && userIndex >= 0) {
        final gap = (userIndex - jobIndex).abs();
        if (gap == 0) {
          score += 15;
        } else if (gap == 1) {
          score += 8;
        } else {
          score += 2;
        }
      }
    }

    final profileComplete = userSkillNames.isNotEmpty && userYearsExperience != null;
    if (profileComplete) score += 5;

    return score.clamp(25, 99).round();
  }

  static String _levelFromYears(int years) {
    if (years < 2) return 'entry';
    if (years < 5) return 'mid';
    if (years < 10) return 'senior';
    if (years < 15) return 'lead';
    return 'executive';
  }
}
