import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // Fetch all active jobs with company details
  static Future<List<Map<String, dynamic>>> getJobs({
    String? workModel,
    String? experienceLevel,
    String? employmentType,
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

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
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
      String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  // Save a job
  static Future<void> saveJob(String userId, String jobId) async {
    await _client.from('saved_jobs').insert({
      'user_id': userId,
      'job_id': jobId,
    });
  }

  // Unsave a job
  static Future<void> unsaveJob(String userId, String jobId) async {
    await _client
        .from('saved_jobs')
        .delete()
        .eq('user_id', userId)
        .eq('job_id', jobId);
  }

  // Get saved jobs
  static Future<List<Map<String, dynamic>>> getSavedJobs(
      String userId) async {
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
    return List<Map<String, dynamic>>.from(response);
  }

  // Apply for a job
  static Future<void> applyForJob(
      String userId, String jobId, String? coverLetter) async {
    await _client.from('applications').insert({
      'user_id': userId,
      'job_id': jobId,
      'cover_letter': coverLetter,
      'status': 'applied',
    });
  }

  // Get user applications
  static Future<List<Map<String, dynamic>>> getApplications(
      String userId) async {
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
    return List<Map<String, dynamic>>.from(response);
  }
}