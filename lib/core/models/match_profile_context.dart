class MatchProfileContext {
  final List<String> skillNames;
  final int? yearsExperience;
  final String? location;
  final String? jobTitle;
  final String preferredWorkModel;
  final String preferredEmploymentType;
  final int? desiredMinSalary;
  final int? desiredMaxSalary;

  const MatchProfileContext({
    this.skillNames = const [],
    this.yearsExperience,
    this.location,
    this.jobTitle,
    this.preferredWorkModel = 'all',
    this.preferredEmploymentType = 'all',
    this.desiredMinSalary,
    this.desiredMaxSalary,
  });

  static MatchProfileContext fromProfile(
    Map<String, dynamic>? profile,
    List<String> skills,
  ) {
    if (profile == null) {
      return MatchProfileContext(skillNames: skills);
    }

    final yearsRaw = profile['years_of_experience'];
    final years = yearsRaw is num
        ? yearsRaw.toInt()
        : int.tryParse('$yearsRaw');

    final minRaw = profile['desired_min_salary'];
    final maxRaw = profile['desired_max_salary'];

    return MatchProfileContext(
      skillNames: skills,
      yearsExperience: years,
      location: profile['location'] as String?,
      jobTitle: profile['job_title'] as String?,
      preferredWorkModel: profile['preferred_work_model'] as String? ?? 'all',
      preferredEmploymentType:
          profile['preferred_employment_type'] as String? ?? 'all',
      desiredMinSalary: minRaw is num
          ? minRaw.toInt()
          : int.tryParse('$minRaw'),
      desiredMaxSalary: maxRaw is num
          ? maxRaw.toInt()
          : int.tryParse('$maxRaw'),
    );
  }
}

class MatchScoreBreakdown {
  final int totalScore;
  final int skillsScore;
  final int experienceScore;
  final int locationScore;
  final int salaryScore;
  final int workModelScore;
  final int titleScore;
  final int profileBonus;
  final List<String> matchedSkills;
  final List<String> missingSkills;

  const MatchScoreBreakdown({
    required this.totalScore,
    required this.skillsScore,
    required this.experienceScore,
    required this.locationScore,
    required this.salaryScore,
    required this.workModelScore,
    required this.titleScore,
    required this.profileBonus,
    this.matchedSkills = const [],
    this.missingSkills = const [],
  });
}
