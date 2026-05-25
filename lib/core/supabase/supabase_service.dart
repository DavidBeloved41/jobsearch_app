import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // Fetch skill names for a user (for match scoring)
  static Future<List<String>> getUserSkillNames(String userId) async {
    final response = await _client
        .from('profile_skills')
        .select('skills(name)')
        .eq('user_id', userId);
    final rows = List<Map<String, dynamic>>.from(response);
    return rows
        .map((row) {
          final skill = row['skills'] as Map<String, dynamic>?;
          return skill?['name'] as String? ?? '';
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  // Search profiles by name (for new conversations)
  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final currentUserId = _client.auth.currentUser?.id;
    var dbQuery = _client
        .from('profiles')
        .select('id, full_name, headline, profile_photo_url')
        .ilike('full_name', '%$query%')
        .limit(20);

    final response = await dbQuery;
    final results = List<Map<String, dynamic>>.from(response);
    if (currentUserId == null) return results;
    return results.where((p) => p['id'] != currentUserId).toList();
  }

  // Get saved job IDs for quick lookup
  static Future<Set<String>> getSavedJobIds(String userId) async {
    final response = await _client
        .from('saved_jobs')
        .select('job_id')
        .eq('user_id', userId);
    return response
        .map((row) => row['job_id'] as String)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  // Mark inbound messages from a partner as read
  static Future<void> markMessagesAsRead(
    String userId,
    String partnerId,
  ) async {
    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('receiver_id', userId)
          .eq('sender_id', partnerId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('SupabaseService: markMessagesAsRead: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllSkills() async {
    final response = await _client.from('skills').select().order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<String>> getDistinctIndustries() async {
    final response = await _client
        .from('companies')
        .select('industry')
        .not('industry', 'is', null);
    final industries = <String>{};
    for (final row in response) {
      final industry = row['industry'] as String?;
      if (industry != null && industry.trim().isNotEmpty) {
        industries.add(industry.trim());
      }
    }
    return industries.toList()..sort();
  }

  // Fetch all active jobs with company details
  static Future<List<Map<String, dynamic>>> getJobs({
    String? workModel,
    String? experienceLevel,
    String? employmentType,
    String? searchQuery,
    int? minSalary,
    int? maxSalary,
    String? location,
    String? industry,
    String? techStack,
  }) async {
    var query = _client
        .from('jobs')
        .select('''
          *,
          companies (
            id,
            name,
            logo_url,
            industry,
            average_rating
          )
        ''')
        .eq('is_active', true);

    if (workModel != null && workModel != 'all') {
      query = query.eq('work_model', workModel);
    }

    if (experienceLevel != null) {
      query = query.eq('experience_level', experienceLevel);
    }

    if (employmentType != null) {
      query = query.eq('employment_type', employmentType);
    }

    if (location != null && location.trim().isNotEmpty) {
      query = query.ilike('location', '%${location.trim()}%');
    }

    final response = await query.order('created_at', ascending: false);
    var jobs = List<Map<String, dynamic>>.from(response);

    if (industry != null && industry.trim().isNotEmpty) {
      final ind = industry.trim().toLowerCase();
      jobs = jobs.where((job) {
        final company = job['companies'] as Map<String, dynamic>?;
        final jobIndustry = (company?['industry'] as String? ?? '').toLowerCase();
        return jobIndustry.contains(ind);
      }).toList();
    }

    if (minSalary != null || maxSalary != null) {
      jobs = jobs.where((job) {
        final jobMin = (job['salary_min'] as num?)?.toInt() ?? 0;
        final jobMax = (job['salary_max'] as num?)?.toInt() ?? 0;
        if (minSalary != null && jobMax < minSalary) return false;
        if (maxSalary != null && jobMin > maxSalary) return false;
        return true;
      }).toList();
    }

    if (techStack != null && techStack.trim().isNotEmpty) {
      final tech = techStack.trim().toLowerCase();
      jobs = jobs.where((job) {
        final text = [
          job['title'] as String? ?? '',
          job['description'] as String? ?? '',
        ].join(' ').toLowerCase();
        return text.contains(tech);
      }).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      jobs = jobs.where((job) {
        final company = job['companies'] as Map<String, dynamic>?;
        final haystack = [
          job['title'] as String? ?? '',
          job['location'] as String? ?? '',
          job['description'] as String? ?? '',
          company?['name'] as String? ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    return jobs;
  }

  // Fetch single job by id
  static Future<Map<String, dynamic>?> getJobById(String jobId) async {
    final response = await _client
        .from('jobs')
        .select('''
          *,
          companies (
            id,
            name,
            logo_url,
            industry,
            average_rating,
            website,
            description
          )
        ''')
        .eq('id', jobId)
        .single();
    return response;
  }

  // Fetch user profile
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  // Update user profile
  static Future<void> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  // Save a job
  static Future<void> saveJob(String userId, String jobId) async {
    try {
      debugPrint('SupabaseService: Saving job $jobId for user $userId');
      await _client.from('saved_jobs').insert({
        'user_id': userId,
        'job_id': jobId,
      });
      debugPrint('SupabaseService: Job saved successfully');
    } catch (e) {
      debugPrint('SupabaseService: Error saving job: $e');
      rethrow;
    }
  }

  // Unsave a job
  static Future<void> unsaveJob(String userId, String jobId) async {
    try {
      debugPrint('SupabaseService: Unsaving job $jobId for user $userId');
      await _client
          .from('saved_jobs')
          .delete()
          .eq('user_id', userId)
          .eq('job_id', jobId);
      debugPrint('SupabaseService: Job unsaved successfully');
    } catch (e) {
      debugPrint('SupabaseService: Error unsaving job: $e');
      rethrow;
    }
  }

  // Get saved jobs
  static Future<List<Map<String, dynamic>>> getSavedJobs(String userId) async {
    try {
      debugPrint('SupabaseService: Fetching saved jobs for user $userId');
      final response = await _client
          .from('saved_jobs')
          .select('''
          *,
          jobs (
            *,
            companies (
              name,
              logo_url
            )
          )
        ''')
          .eq('user_id', userId);
      debugPrint('SupabaseService: Fetched ${response.length} saved jobs');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: Error fetching saved jobs: $e');
      rethrow;
    }
  }

  // Apply for a job
  static Future<void> applyForJob(
    String userId,
    String jobId,
    String? coverLetter,
  ) async {
    try {
      debugPrint('SupabaseService: Applying for job $jobId with user $userId');
      await _client.from('applications').insert({
        'user_id': userId,
        'job_id': jobId,
        'cover_letter': coverLetter,
        'status': 'applied',
      });
      debugPrint('SupabaseService: Application submitted successfully');
    } catch (e) {
      debugPrint('SupabaseService: Error applying for job: $e');
      rethrow;
    }
  }

  // Get user applications
  static Future<List<Map<String, dynamic>>> getApplications(
    String userId,
  ) async {
    try {
      debugPrint('SupabaseService: Fetching applications for user $userId');
      final response = await _client
          .from('applications')
          .select('''
          *,
          jobs (
            title,
            location,
            work_model,
            companies (
              name,
              logo_url
            )
          )
        ''')
          .eq('user_id', userId)
          .order('applied_at', ascending: false);
      debugPrint('SupabaseService: Fetched ${response.length} applications');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: Error fetching applications: $e');
      rethrow;
    }
  }

  static Future<void> updateApplicationStatus(
    String applicationId,
    String status,
  ) async {
    await _client.from('applications').update({'status': status}).eq(
      'id',
      applicationId,
    );
  }
}
