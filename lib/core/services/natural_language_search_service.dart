import '../models/job_filters.dart';
import 'ai_service.dart';

class NaturalLanguageSearchResult {
  final String? keywordQuery;
  final JobFilters filters;
  final String? experienceLevel;
  final String summary;

  const NaturalLanguageSearchResult({
    this.keywordQuery,
    this.filters = const JobFilters(),
    this.experienceLevel,
    this.summary = '',
  });

  bool get hasStructuredFilters =>
      filters.hasAdvancedFilters ||
      filters.workModel != 'all' ||
      filters.employmentType != 'all' ||
      experienceLevel != null;
}

class NaturalLanguageSearchService {
  static NaturalLanguageSearchResult parse(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      return const NaturalLanguageSearchResult();
    }

    var workModel = 'all';
    var employmentType = 'all';
    String? experienceLevel;
    int? minSalary;
    int? maxSalary;
    var location = '';
    var industry = '';
    var techStack = '';
    final applied = <String>[];

    final workModelMatch = RegExp(
      r'\b(remote|hybrid|on[- ]site|onsite)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (workModelMatch != null) {
      final raw = workModelMatch.group(1)!.toLowerCase();
      workModel = raw.contains('site') ? 'on-site' : raw;
      applied.add(workModelMatch.group(0)!);
    }

    final employmentMatch = RegExp(
      r'\b(full[- ]time|part[- ]time|contract|freelance)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (employmentMatch != null) {
      final raw = employmentMatch.group(1)!.toLowerCase();
      employmentType = raw.contains('full') ? 'full-time' : 'contract';
      applied.add(employmentMatch.group(0)!);
    }

    final levelMatch = RegExp(
      r'\b(entry[- ]level|junior|mid[- ]level|senior|lead|executive|director)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (levelMatch != null) {
      final raw = levelMatch.group(1)!.toLowerCase();
      experienceLevel = switch (raw) {
        'junior' || 'entry-level' || 'entry level' => 'entry',
        'mid-level' || 'mid level' => 'mid',
        'senior' => 'senior',
        'lead' || 'director' => 'lead',
        'executive' => 'executive',
        _ => 'mid',
      };
      applied.add(levelMatch.group(0)!);
    }

    final salaryOverMatch = RegExp(
      r'(?:salary|pay|earning(?:s)?)\s*(?:over|above|more than|at least|>=?)\s*'
      r'(?:[\$£€])?\s*(\d[\d,]*)\s*(k|K|000)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (salaryOverMatch != null) {
      minSalary = _parseSalary(
        salaryOverMatch.group(1)!,
        salaryOverMatch.group(2),
      );
      applied.add(salaryOverMatch.group(0)!);
    } else {
      final overMatch = RegExp(
        r'(?:over|above|more than|at least)\s*(?:[\$£€])?\s*(\d[\d,]*)\s*(k|K|000)?',
        caseSensitive: false,
      ).firstMatch(text);
      if (overMatch != null) {
        minSalary = _parseSalary(overMatch.group(1)!, overMatch.group(2));
        applied.add(overMatch.group(0)!);
      }
    }

    final salaryUnderMatch = RegExp(
      r'(?:under|below|less than|up to|max)\s*(?:[\$£€])?\s*(\d[\d,]*)\s*(k|K|000)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (salaryUnderMatch != null) {
      maxSalary = _parseSalary(
        salaryUnderMatch.group(1)!,
        salaryUnderMatch.group(2),
      );
      applied.add(salaryUnderMatch.group(0)!);
    }

    final locationMatch = RegExp(
      r"\b(?:in|near|around|based in|located in)\s+([A-Za-z][A-Za-z\s,'-]{1,40})",
      caseSensitive: false,
    ).firstMatch(text);
    if (locationMatch != null) {
      location = locationMatch.group(1)!.trim();
      location = location.replaceAll(
        RegExp(
          r'\s+(with|that|where|for|and|or|remote|hybrid).*$',
          caseSensitive: false,
        ),
        '',
      );
      applied.add(locationMatch.group(0)!);
    }

    final industryMatch = RegExp(
      r'\b(?:in|within)\s+(?:the\s+)?(technology|finance|healthcare|marketing|engineering|retail|education)\s+(?:industry|sector)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (industryMatch != null) {
      industry = _capitalize(industryMatch.group(1)!);
      applied.add(industryMatch.group(0)!);
    }

    final techMatch = RegExp(
      r'\b(?:using|with|knowing|stack:?|skills?:?)\s+([A-Za-z0-9+#.\s,/-]{2,40})',
      caseSensitive: false,
    ).firstMatch(text);
    if (techMatch != null) {
      techStack = techMatch
          .group(1)!
          .trim()
          .replaceAll(
            RegExp(r'\s+(in|with|for|and|or).*$', caseSensitive: false),
            '',
          );
      applied.add(techMatch.group(0)!);
    }

    var keyword = text;
    for (final fragment in applied) {
      keyword = keyword.replaceAll(fragment, ' ');
    }
    keyword = keyword
        .replaceAll(
          RegExp(
            r'\b(show me|find|search for|looking for|roles?|jobs?|positions?)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final filters = JobFilters(
      workModel: workModel,
      employmentType: employmentType,
      minSalary: minSalary,
      maxSalary: maxSalary,
      location: location,
      industry: industry,
      techStack: techStack,
    );

    final parts = <String>[];
    if (experienceLevel != null) parts.add(_capitalize(experienceLevel));
    if (keyword.isNotEmpty) parts.add(keyword);
    if (location.isNotEmpty) parts.add('in $location');
    if (workModel != 'all') parts.add(workModel);
    if (minSalary != null) parts.add('≥ GH₵${minSalary ~/ 1000}k');
    if (techStack.isNotEmpty) parts.add('tech: $techStack');

    return NaturalLanguageSearchResult(
      keywordQuery: keyword.isEmpty ? null : keyword,
      filters: filters,
      experienceLevel: experienceLevel,
      summary: parts.isEmpty ? input : parts.join(' · '),
    );
  }

  /// Tries AI parsing first, falls back to rule-based [parse].
  static Future<NaturalLanguageSearchResult> parseSmart(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const NaturalLanguageSearchResult();

    if (AiService.isConfigured) {
      final json = await AiService.parseJobSearchJson(trimmed);
      if (json != null) {
        final filters = JobFilters(
          workModel: json['work_model'] as String? ?? 'all',
          employmentType: json['employment_type'] as String? ?? 'all',
          minSalary: (json['min_salary'] as num?)?.toInt(),
          maxSalary: (json['max_salary'] as num?)?.toInt(),
          location: json['location'] as String? ?? '',
          industry: json['industry'] as String? ?? '',
          techStack: json['tech_stack'] as String? ?? '',
        );
        final keyword = json['keyword'] as String?;
        final level = json['experience_level'] as String?;
        final parts = <String>[];
        if (level != null) parts.add(_capitalize(level));
        if (keyword != null && keyword.isNotEmpty) parts.add(keyword);
        if (filters.location.isNotEmpty) parts.add('in ${filters.location}');
        return NaturalLanguageSearchResult(
          keywordQuery: keyword,
          filters: filters,
          experienceLevel: level,
          summary: 'AI · ${parts.isEmpty ? trimmed : parts.join(' · ')}',
        );
      }
    }

    return parse(trimmed);
  }

  static int _parseSalary(String amount, String? suffix) {
    final cleaned = amount.replaceAll(',', '');
    var value = int.tryParse(cleaned) ?? 0;
    if (suffix != null && (suffix.toLowerCase() == 'k' || suffix == '000')) {
      value *= 1000;
    } else if (value > 0 && value < 1000) {
      value *= 1000;
    }
    return value;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
