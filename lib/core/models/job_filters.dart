class JobFilters {
  final String workModel; // all, remote, hybrid, on-site
  final String employmentType; // all, full-time, contract
  final int? minSalary;
  final int? maxSalary;
  final String location;
  final String industry;
  final String techStack;

  const JobFilters({
    this.workModel = 'all',
    this.employmentType = 'all',
    this.minSalary,
    this.maxSalary,
    this.location = '',
    this.industry = '',
    this.techStack = '',
  });

  bool get hasAdvancedFilters =>
      minSalary != null ||
      maxSalary != null ||
      location.isNotEmpty ||
      industry.isNotEmpty ||
      techStack.isNotEmpty;

  int get activeCount {
    var n = 0;
    if (minSalary != null || maxSalary != null) n++;
    if (location.isNotEmpty) n++;
    if (industry.isNotEmpty) n++;
    if (techStack.isNotEmpty) n++;
    return n;
  }

  JobFilters copyWith({
    String? workModel,
    String? employmentType,
    int? minSalary,
    int? maxSalary,
    String? location,
    String? industry,
    String? techStack,
    bool clearMinSalary = false,
    bool clearMaxSalary = false,
  }) {
    return JobFilters(
      workModel: workModel ?? this.workModel,
      employmentType: employmentType ?? this.employmentType,
      minSalary: clearMinSalary ? null : (minSalary ?? this.minSalary),
      maxSalary: clearMaxSalary ? null : (maxSalary ?? this.maxSalary),
      location: location ?? this.location,
      industry: industry ?? this.industry,
      techStack: techStack ?? this.techStack,
    );
  }
}
