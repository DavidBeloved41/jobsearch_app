import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ai_service.dart';
import '../services/offline_cache_service.dart';
import '../services/resume_text_service.dart';
import '../supabase/supabase_service.dart';

class EasyApplyService {
  static Future<String?> buildCoverLetter({
    required Map<String, dynamic> job,
    required Map<String, dynamic>? profile,
    required List<String> skillNames,
    String? resumeText,
  }) async {
    if (AiService.isConfigured) {
      final aiLetter = await AiService.generateCoverLetter(
        job: job,
        profile: profile,
        skills: skillNames,
        resumeText: resumeText,
      );
      if (aiLetter != null && aiLetter.trim().length > 80) {
        return aiLetter.trim();
      }
    }

    final draft = await OfflineCacheService.getResumeDraft();
    if (draft != null && draft.trim().length > 80) {
      return draft.trim();
    }

    final company = job['companies'] as Map<String, dynamic>?;
    final companyName = company?['name'] as String? ?? 'your company';
    final jobTitle = job['title'] as String? ?? 'this role';
    final fullName = profile?['full_name'] as String? ?? '';
    final userTitle = profile?['job_title'] as String? ?? '';
    final yearsRaw = profile?['years_of_experience'];
    final years = yearsRaw is num
        ? yearsRaw.toInt()
        : int.tryParse('$yearsRaw');
    final skillsLine = skillNames.take(6).join(', ');

    final buffer = StringBuffer();
    buffer.writeln('Dear Hiring Manager,');
    buffer.writeln();
    buffer.writeln(
      'I am writing to express my interest in the $jobTitle position at $companyName.',
    );
    if (userTitle.isNotEmpty || years != null) {
      buffer.write('As a');
      if (userTitle.isNotEmpty) buffer.write(' $userTitle');
      if (years != null) buffer.write(' with $years years of experience');
      buffer.writeln(', I believe I am a strong fit for this opportunity.');
    }
    if (skillsLine.isNotEmpty) {
      buffer.writeln(
        'My background includes skills in $skillsLine, which align closely with your requirements.',
      );
    }
    buffer.writeln();
    buffer.writeln(
      'I would welcome the opportunity to discuss how I can contribute to your team.',
    );
    buffer.writeln();
    buffer.writeln('Best regards,');
    if (fullName.isNotEmpty) buffer.writeln(fullName);

    return buffer.toString();
  }

  static Future<Map<String, dynamic>> getApplyPayload({
    required String userId,
    required Map<String, dynamic> job,
  }) async {
    final profile = await SupabaseService.getProfile(userId);
    final skills = await SupabaseService.getUserSkillNames(userId);
    final resumeText = await ResumeTextService.fromProfile(profile);
    final coverLetter = await buildCoverLetter(
      job: job,
      profile: profile,
      skillNames: skills,
      resumeText: resumeText,
    );
    return {
      'coverLetter': coverLetter,
      'resumeUrl': profile?['resume_url'] as String?,
      'profileSnapshot': {
        'full_name': profile?['full_name'],
        'email': Supabase.instance.client.auth.currentUser?.email,
        'phone_number': profile?['phone_number'],
        'location': profile?['location'],
        'job_title': profile?['job_title'],
        'years_of_experience': profile?['years_of_experience'],
        'resume_url': profile?['resume_url'],
      },
    };
  }
}
