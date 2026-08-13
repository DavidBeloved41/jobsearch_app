import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static bool get isConfigured {
    final key = dotenv.env['OPENAI_API_KEY'];
    return key != null && key.trim().isNotEmpty && key != 'your_key_here';
  }

  static String get _model => dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o-mini';

  static String get _baseUrl =>
      dotenv.env['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1';

  static Future<String?> complete({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.4,
  }) async {
    if (!isConfigured) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY']}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'temperature': temperature,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('AiService: HTTP ${response.statusCode} ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final message = choices.first['message'] as Map<String, dynamic>?;
      return message?['content'] as String?;
    } catch (e) {
      debugPrint('AiService: complete $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> parseJobSearchJson(String query) async {
    final raw = await complete(
      systemPrompt: '''
You extract job search filters from natural language. Reply ONLY with valid JSON, no markdown.
Schema:
{
  "keyword": "string or null",
  "work_model": "all|remote|hybrid|on-site",
  "employment_type": "all|full-time|contract",
  "experience_level": "entry|mid|senior|lead|executive or null",
  "min_salary": number or null,
  "max_salary": number or null,
  "location": "string or null",
  "industry": "string or null",
  "tech_stack": "string or null"
}
Use annual USD salaries. Convert "60k" to 60000.''',
      userPrompt: query,
      temperature: 0.1,
    );
    if (raw == null) return null;

    try {
      final cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return Map<String, dynamic>.from(jsonDecode(cleaned) as Map);
    } catch (e) {
      debugPrint('AiService: parseJobSearchJson $e');
      return null;
    }
  }

  static Future<String?> generateCoverLetter({
    required Map<String, dynamic> job,
    required Map<String, dynamic>? profile,
    required List<String> skills,
  }) async {
    final company = job['companies'] as Map<String, dynamic>?;
    return complete(
      systemPrompt:
          'Write a concise, professional job cover letter (180-250 words). No placeholders.',
      userPrompt: '''
Job: ${job['title']}
Company: ${company?['name'] ?? 'Unknown'}
Description excerpt: ${(job['description'] as String? ?? '').substring(0, (job['description'] as String? ?? '').length.clamp(0, 800))}

Candidate: ${profile?['full_name'] ?? 'Unknown'}
Title: ${profile?['job_title']}
Experience: ${profile?['years_of_experience']} years
Location: ${profile?['location']}
Skills: ${skills.join(', ')}
Bio: ${profile?['bio'] ?? ''}''',
      temperature: 0.5,
    );
  }

  static Future<String?> generateResumeDraft({
    required Map<String, dynamic>? profile,
    required List<String> skills,
    String? targetRole,
  }) async {
    return complete(
      systemPrompt:
          'Write an ATS-friendly resume draft in plain text with sections: Summary, Skills, Experience, Education. Use bullet points.',
      userPrompt: '''
Target role: ${targetRole ?? profile?['job_title'] ?? 'Professional'}
Name: ${profile?['full_name']}
Experience years: ${profile?['years_of_experience']}
Location: ${profile?['location']}
Skills: ${skills.join(', ')}
Bio: ${profile?['bio'] ?? ''}''',
      temperature: 0.5,
    );
  }

  static Future<String?> generateMatchInsight({
    required Map<String, dynamic> job,
    required int matchScore,
    required List<String> matchedSkills,
    required List<String> missingSkills,
  }) async {
    final company = job['companies'] as Map<String, dynamic>?;
    return complete(
      systemPrompt:
          'Give 2-3 short sentences explaining why this job matches the candidate. Be specific and encouraging.',
      userPrompt: '''
Job: ${job['title']} at ${company?['name']}
Match score: $matchScore%
Matched skills: ${matchedSkills.join(', ')}
Gaps: ${missingSkills.join(', ')}''',
      temperature: 0.6,
    );
  }

  static Future<List<String>?> rankJobIds({
    required List<Map<String, dynamic>> jobs,
    required Map<String, dynamic>? profile,
    required List<String> skills,
  }) async {
    if (jobs.length <= 1) return null;

    final summaries = jobs.take(15).map((j) {
      final c = j['companies'] as Map<String, dynamic>?;
      return {
        'id': j['id'],
        'title': j['title'],
        'company': c?['name'],
        'location': j['location'],
        'work_model': j['work_model'],
      };
    }).toList();

    final raw = await complete(
      systemPrompt:
          'Rank jobs by fit for the candidate. Reply ONLY with a JSON array of job id strings, best first.',
      userPrompt: '''
Candidate title: ${profile?['job_title']}
Skills: ${skills.join(', ')}
Experience: ${profile?['years_of_experience']} years
Jobs: ${jsonEncode(summaries)}''',
      temperature: 0.2,
    );
    if (raw == null) return null;

    try {
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final list = jsonDecode(cleaned) as List;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('AiService: rankJobIds $e');
      return null;
    }
  }
}

