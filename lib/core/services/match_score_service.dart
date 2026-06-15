import '../models/match_profile_context.dart';

class MatchScoreService {
  static const _experienceLevels = [
    'entry',
    'mid',
    'senior',
    'lead',
    'executive',
  ];

  static int calculate({
    required Map<String, dynamic> job,
    required List<String> userSkillNames,
    int? userYearsExperience,
    MatchProfileContext? profile,
  }) {
    return calculateDetailed(
      job: job,
      userSkillNames: userSkillNames,
      userYearsExperience: userYearsExperience,
      profile: profile,
    ).totalScore;
  }

  static MatchScoreBreakdown calculateDetailed({
    required Map<String, dynamic> job,
    required List<String> userSkillNames,
    int? userYearsExperience,
    MatchProfileContext? profile,
  }) {
    final ctx = profile ??
        MatchProfileContext(
          skillNames: userSkillNames,
          yearsExperience: userYearsExperience,
        );

    final skills = ctx.skillNames.isNotEmpty ? ctx.skillNames : userSkillNames;
    final years = ctx.yearsExperience ?? userYearsExperience;

    var skillsScore = 0.0;
    var experienceScore = 0.0;
    var locationScore = 0.0;
    var salaryScore = 0.0;
    var workModelScore = 0.0;
    var titleScore = 0.0;
    var profileBonus = 0.0;

    final matchedSkills = <String>[];
    final missingSkills = <String>[];

    final jobText = [
      job['title'] as String? ?? '',
      job['description'] as String? ?? '',
    ].join(' ').toLowerCase();

    if (skills.isNotEmpty && jobText.isNotEmpty) {
      for (final skill in skills) {
        final name = skill.trim().toLowerCase();
        if (name.length < 2) continue;
        if (jobText.contains(name)) {
          matchedSkills.add(skill);
        } else {
          missingSkills.add(skill);
        }
      }
      final skillRatio = matchedSkills.length / skills.length;
      skillsScore = skillRatio * 35;
    } else if (skills.isEmpty) {
      skillsScore = 8;
    }

    final jobLevel = (job['experience_level'] as String? ?? '').toLowerCase();
    if (jobLevel.isNotEmpty && years != null) {
      final userLevel = _levelFromYears(years);
      final jobIndex = _experienceLevels.indexOf(jobLevel);
      final userIndex = _experienceLevels.indexOf(userLevel);
      if (jobIndex >= 0 && userIndex >= 0) {
        final gap = (userIndex - jobIndex).abs();
        if (gap == 0) {
          experienceScore = 18;
        } else if (gap == 1) {
          experienceScore = 10;
        } else if (gap == 2) {
          experienceScore = 4;
        }
      }
    }

    final userLocation = (ctx.location ?? '').trim().toLowerCase();
    final jobLocation = (job['location'] as String? ?? '').trim().toLowerCase();
    if (userLocation.isNotEmpty && jobLocation.isNotEmpty) {
      if (jobLocation.contains(userLocation) ||
          userLocation.contains(jobLocation)) {
        locationScore = 12;
      } else {
        final userParts = userLocation.split(RegExp(r'[,\s]+'));
        if (userParts.any((p) => p.length > 2 && jobLocation.contains(p))) {
          locationScore = 8;
        }
      }
    }

    final jobMin = (job['salary_min'] as num?)?.toInt() ?? 0;
    final jobMax = (job['salary_max'] as num?)?.toInt() ?? 0;
    if (ctx.desiredMinSalary != null && jobMax > 0) {
      if (jobMax >= ctx.desiredMinSalary!) {
        salaryScore = 12;
      } else if (jobMax >= (ctx.desiredMinSalary! * 0.85).round()) {
        salaryScore = 6;
      }
    } else if (ctx.desiredMaxSalary != null && jobMin > 0) {
      if (jobMin <= ctx.desiredMaxSalary!) {
        salaryScore = 10;
      }
    } else if (jobMin > 0 || jobMax > 0) {
      salaryScore = 4;
    }

    final jobWorkModel = (job['work_model'] as String? ?? '').toLowerCase();
    final preferredWork = ctx.preferredWorkModel.toLowerCase();
    if (preferredWork != 'all' && jobWorkModel.isNotEmpty) {
      workModelScore = jobWorkModel == preferredWork ? 10 : 2;
    } else if (jobWorkModel == 'remote') {
      workModelScore = 3;
    }

    final userTitle = (ctx.jobTitle ?? '').trim().toLowerCase();
    final jobTitle = (job['title'] as String? ?? '').trim().toLowerCase();
    if (userTitle.isNotEmpty && jobTitle.isNotEmpty) {
      final userWords = userTitle.split(RegExp(r'\s+')).where((w) => w.length > 2);
      final matches = userWords.where(jobTitle.contains).length;
      if (matches >= 2) {
        titleScore = 10;
      } else if (matches == 1) {
        titleScore = 6;
      }
    }

    final profileComplete =
        skills.isNotEmpty && years != null && userLocation.isNotEmpty;
    if (profileComplete) profileBonus = 5;

    final employmentType =
        (job['employment_type'] as String? ?? '').toLowerCase();
    final preferredEmployment = ctx.preferredEmploymentType.toLowerCase();
    if (preferredEmployment != 'all' &&
        employmentType.isNotEmpty &&
        employmentType == preferredEmployment) {
      profileBonus += 3;
    }

    final total = (skillsScore +
            experienceScore +
            locationScore +
            salaryScore +
            workModelScore +
            titleScore +
            profileBonus)
        .clamp(25, 99)
        .round();

    return MatchScoreBreakdown(
      totalScore: total,
      skillsScore: skillsScore.round(),
      experienceScore: experienceScore.round(),
      locationScore: locationScore.round(),
      salaryScore: salaryScore.round(),
      workModelScore: workModelScore.round(),
      titleScore: titleScore.round(),
      profileBonus: profileBonus.round(),
      matchedSkills: matchedSkills,
      missingSkills: missingSkills.take(8).toList(),
    );
  }

  static String _levelFromYears(int years) {
    if (years < 2) return 'entry';
    if (years < 5) return 'mid';
    if (years < 10) return 'senior';
    if (years < 15) return 'lead';
    return 'executive';
  }
}
