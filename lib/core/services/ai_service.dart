import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  static bool get isConfigured => true;

  static Future<Map<String, dynamic>?> _invokeJson(
    String action,
    Map<String, dynamic> input,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-career-assistant',
        body: {'action': action, 'input': input},
      );
      final data = response.data;
      if (data is! Map || data['result'] is! Map) return null;
      return Map<String, dynamic>.from(data['result'] as Map);
    } catch (error) {
      debugPrint('AiService: $action failed: $error');
      return null;
    }
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static Future<String?> complete({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.4,
  }) async {
    final result = await _invokeJson('career_assistant', {
      'question': userPrompt,
      'system_context': systemPrompt,
    });
    return result?['answer'] as String?;
  }

  static Future<Map<String, dynamic>?> parseJobSearchJson(String query) =>
      _invokeJson('search_filters', {'query': query});

  static Future<String?> generateCoverLetter({
    required Map<String, dynamic> job,
    required Map<String, dynamic>? profile,
    required List<String> skills,
    String? resumeText,
  }) async {
    final result = await _invokeJson('cover_letter', {
      'job': _safeJob(job),
      'candidate': _safeProfile(profile),
      'skills': skills,
      'resume_text': resumeText ?? '',
    });
    final letter = result?['cover_letter'];
    return letter is String && letter.trim().isNotEmpty ? letter.trim() : null;
  }

  static Future<String?> generateResumeDraft({
    required Map<String, dynamic>? profile,
    required List<String> skills,
    String? targetRole,
  }) async {
    final result = await _invokeJson('career_assistant', {
      'question': 'Create an ATS-friendly resume draft for the target role.',
      'candidate': _safeProfile(profile),
      'skills': skills,
      'target_role': targetRole,
    });
    return result?['answer'] as String?;
  }

  static Future<Map<String, dynamic>?> analyzeJobMatch({
    required Map<String, dynamic> job,
    required Map<String, dynamic>? profile,
    required List<String> skills,
    required String? resumeText,
    required int deterministicScore,
  }) async {
    final result = await _invokeJson('job_match', {
      'job': _safeJob(job),
      'candidate': _safeProfile(profile),
      'skills': skills,
      'resume_text': resumeText ?? '',
      'deterministic_score': deterministicScore,
    });
    return parseJobMatchResponse(result);
  }

  static Map<String, dynamic>? parseJobMatchResponse(
    Map<String, dynamic>? result,
  ) {
    final score = result?['match_score'];
    if (score is! num || score < 0 || score > 100) return null;
    result!['match_score'] = score.round();
    result['matching_skills'] = _stringList(result['matching_skills']);
    result['missing_skills'] = _stringList(result['missing_skills']);
    result['recommendations'] = _stringList(result['recommendations']);
    return result;
  }

  static Future<Map<String, dynamic>?> analyzeSkillsGap({
    required Map<String, dynamic> job,
    required Map<String, dynamic>? profile,
    required List<String> skills,
    required String? resumeText,
  }) async {
    final result = await _invokeJson('skills_gap', {
      'job': _safeJob(job),
      'candidate': _safeProfile(profile),
      'skills': skills,
      'resume_text': resumeText ?? '',
    });
    if (result == null) return null;
    result['existing_skills'] = _stringList(result['existing_skills']);
    result['missing_skills'] = _stringList(result['missing_skills']);
    result['priority_skills'] = _stringList(result['priority_skills']);
    return result;
  }

  static Future<Map<String, dynamic>?> analyzeResume(String resumeText) {
    if (resumeText.trim().isEmpty) return Future.value(null);
    return _invokeJson('resume_analysis', {'resume_text': resumeText});
  }

  static Future<Map<String, dynamic>?> askCareerAssistant({
    required String question,
    required Map<String, dynamic>? profile,
    required List<String> skills,
    String? resumeText,
    Map<String, dynamic>? job,
    Map<String, dynamic>? ats,
    Map<String, dynamic>? skillsGap,
  }) => _invokeJson('career_assistant', {
    'question': question,
    'candidate': _safeProfile(profile),
    'skills': skills,
    'resume_text': resumeText ?? '',
    'job': job == null ? null : _safeJob(job),
    'ats': ats,
    'skills_gap': skillsGap,
  });

  static Future<String?> generateMatchInsight({
    required Map<String, dynamic> job,
    required int matchScore,
    required List<String> matchedSkills,
    required List<String> missingSkills,
  }) async {
    final result = await _invokeJson('match_insight', {
      'job': _safeJob(job),
      'deterministic_score': matchScore,
      'matched_skills': matchedSkills,
      'missing_skills': missingSkills,
    });
    return result?['summary'] as String?;
  }

  static Future<List<String>?> rankJobIds({
    required List<Map<String, dynamic>> jobs,
    required Map<String, dynamic>? profile,
    required List<String> skills,
  }) async {
    if (jobs.length <= 1) return null;
    final result = await _invokeJson('rank_jobs', {
      'candidate': _safeProfile(profile),
      'skills': skills,
      'jobs': jobs.take(15).map(_safeJob).toList(),
    });
    final ids = result == null
        ? const <String>[]
        : _stringList(result['job_ids']);
    final allowed = jobs
        .map((job) => job['id']?.toString())
        .whereType<String>()
        .toSet();
    final ranked = ids.where(allowed.contains).toList();
    return ranked.isEmpty ? null : ranked;
  }

  static Map<String, dynamic> _safeJob(Map<String, dynamic> job) {
    const fields = [
      'id',
      'title',
      'description',
      'required_skills',
      'qualifications',
      'requirements',
      'responsibilities',
      'experience_level',
      'location',
      'work_model',
      'employment_type',
      'salary_min',
      'salary_max',
      'salary_currency',
    ];
    return {
      for (final field in fields)
        if (job.containsKey(field)) field: job[field],
    };
  }

  static Map<String, dynamic> _safeProfile(Map<String, dynamic>? profile) {
    if (profile == null) return const {};
    const fields = [
      'full_name',
      'job_title',
      'years_of_experience',
      'location',
      'bio',
    ];
    return {
      for (final field in fields)
        if (profile.containsKey(field)) field: profile[field],
    };
  }

  static String? decodeAnswer(dynamic value) => value is String
      ? value
      : value is Map
      ? jsonEncode(value)
      : null;
}
