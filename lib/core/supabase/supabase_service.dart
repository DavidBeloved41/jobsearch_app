import 'package:flutter/foundation.dart';
import 'dart:typed_data';
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
  static Future<List<Map<String, dynamic>>> searchProfiles(
    String query, {
    bool recruitersOnly = false,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    var dbQuery = _client
        .from('profiles')
        .select(
          'id, full_name, headline, profile_photo_url, account_type, company_name',
        )
        .ilike('full_name', '%$query%')
        .limit(20);

    final response = await dbQuery;
    var results = List<Map<String, dynamic>>.from(response);
    if (recruitersOnly) {
      results = results.where(isRecruiterProfile).toList();
    }
    if (currentUserId == null) return results;
    return results.where((p) => p['id'] != currentUserId).toList();
  }

  static bool isRecruiterProfile(Map<String, dynamic> profile) {
    final accountType = (profile['account_type'] as String? ?? '')
        .toLowerCase();
    if (accountType == 'recruiter' || accountType == 'employer') {
      return true;
    }
    final headline = (profile['headline'] as String? ?? '').toLowerCase();
    return headline.contains('recruiter') ||
        headline.contains('talent acquisition') ||
        headline.contains('hiring manager');
  }

  static Future<List<Map<String, dynamic>>> searchRecruiters(
    String query,
  ) async {
    return searchProfiles(query, recruitersOnly: true);
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
        final jobIndustry = (company?['industry'] as String? ?? '')
            .toLowerCase();
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

  static Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    try {
      final response = await _client
          .from('companies')
          .select()
          .eq('id', companyId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('SupabaseService: getCompanyById $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getCompanyReviews(
    String companyId,
  ) async {
    try {
      final response = await _client
          .from('company_reviews')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: getCompanyReviews fallback $e');
      return _fallbackCompanyReviews(companyId);
    }
  }

  static List<Map<String, dynamic>> _fallbackCompanyReviews(String companyId) {
    return [
      {
        'id': '${companyId}_1',
        'rating': 4,
        'title': 'Great culture and growth',
        'review_text':
            'Collaborative team, clear career paths, and good work-life balance. Management listens to feedback.',
        'reviewer_role': 'Software Engineer',
        'created_at': DateTime.now()
            .subtract(const Duration(days: 45))
            .toIso8601String(),
      },
      {
        'id': '${companyId}_2',
        'rating': 5,
        'title': 'Strong learning environment',
        'review_text':
            'Excellent mentorship and opportunities to work on meaningful projects. Benefits are competitive.',
        'reviewer_role': 'Product Manager',
        'created_at': DateTime.now()
            .subtract(const Duration(days: 90))
            .toIso8601String(),
      },
      {
        'id': '${companyId}_3',
        'rating': 3,
        'title': 'Fast-paced but rewarding',
        'review_text':
            'High expectations and busy periods, but you learn quickly and see direct impact from your work.',
        'reviewer_role': 'Marketing Specialist',
        'created_at': DateTime.now()
            .subtract(const Duration(days: 120))
            .toIso8601String(),
      },
    ];
  }

  static Future<Map<String, dynamic>> getCompanyGrowthPath(
    String companyId, {
    String? industry,
  }) async {
    try {
      final response = await _client
          .from('company_growth_paths')
          .select()
          .eq('company_id', companyId)
          .maybeSingle();
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('SupabaseService: getCompanyGrowthPath fallback $e');
    }
    return _fallbackGrowthPath(industry);
  }

  static Map<String, dynamic> _fallbackGrowthPath(String? industry) {
    final ind = (industry ?? 'Technology').toLowerCase();
    if (ind.contains('finance')) {
      return {
        'promotion_timeline': '18–24 months average to next level',
        'levels': ['Analyst', 'Associate', 'Senior Associate', 'Director'],
        'growth_rate': 'Stable',
        'internal_mobility': 'High — cross-department moves common',
      };
    }
    if (ind.contains('health')) {
      return {
        'promotion_timeline': '24–36 months average to next level',
        'levels': ['Coordinator', 'Specialist', 'Manager', 'Director'],
        'growth_rate': 'Growing',
        'internal_mobility': 'Moderate — clinical vs admin tracks',
      };
    }
    return {
      'promotion_timeline': '12–18 months average to next level',
      'levels': ['Junior', 'Mid-level', 'Senior', 'Lead', 'Principal'],
      'growth_rate': 'Fast',
      'internal_mobility': 'High — engineering, product, and design paths',
    };
  }

  static Future<List<Map<String, dynamic>>> getInboundRecruiterInterests(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('candidate_interests')
          .select('''
            *,
            recruiter:recruiter_id (
              id,
              full_name,
              headline,
              company_name,
              profile_photo_url
            )
          ''')
          .eq('candidate_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: candidate_interests fallback $e');
    }

    try {
      final notifications = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('type', 'recruiter_interest')
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(notifications);
    } catch (e) {
      debugPrint('SupabaseService: recruiter_interest notifications $e');
    }

    return _inboundInterestsFromRecruiterMessages(userId);
  }

  static Future<List<Map<String, dynamic>>>
  _inboundInterestsFromRecruiterMessages(String userId) async {
    try {
      final messages = await _client
          .from('messages')
          .select('sender_id, content, created_at')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final senderIds = <String>{};
      for (final msg in messages) {
        final id = msg['sender_id'] as String?;
        if (id != null) senderIds.add(id);
      }
      if (senderIds.isEmpty) return [];

      final profiles = await _client
          .from('profiles')
          .select(
            'id, full_name, headline, company_name, profile_photo_url, account_type',
          )
          .inFilter('id', senderIds.toList());

      final recruiterIds = profiles
          .where(isRecruiterProfile)
          .map((p) => p['id'] as String)
          .toSet();

      final results = <Map<String, dynamic>>[];
      for (final msg in messages) {
        final senderId = msg['sender_id'] as String? ?? '';
        if (!recruiterIds.contains(senderId)) continue;
        final profile = profiles.firstWhere(
          (p) => p['id'] == senderId,
          orElse: () => <String, dynamic>{},
        );
        if (profile.isEmpty) continue;
        results.add({
          'id': 'msg_$senderId',
          'message': msg['content'],
          'created_at': msg['created_at'],
          'recruiter': profile,
        });
        if (results.length >= 10) break;
      }
      return results;
    } catch (e) {
      debugPrint('SupabaseService: recruiter messages fallback $e');
      return [];
    }
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

  // Create user profile (called during signup or if missing)
  static Future<void> createProfile(
    String userId, {
    String? email,
    String? fullName,
  }) async {
    try {
      debugPrint('SupabaseService: Creating profile for user $userId');
      await _client.from('profiles').insert({
        'id': userId,
        if (email != null) 'email': email,
        if (fullName != null) 'full_name': fullName,
        'created_at': DateTime.now().toIso8601String(),
        'is_open_to_work': true,
      });
      debugPrint('SupabaseService: Profile created successfully');
    } catch (e) {
      debugPrint('SupabaseService: Error creating profile: $e');
      // Don't rethrow - profile might already exist or be created by trigger
    }
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

      // FIX: Check if profile exists before saving job
      // This prevents FK constraint violation: "saved_jobs_user_id_fkey"
      final profile = await getProfile(userId);
      if (profile == null) {
        debugPrint(
          'SupabaseService: Profile not found for user $userId, attempting to create',
        );
        await createProfile(userId);
      }

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

  // Express interest in a job
  static Future<void> expressInterestInJob(String userId, String jobId) async {
    try {
      debugPrint(
        'SupabaseService: Expressing interest in job $jobId for user $userId',
      );

      // Check if profile exists before expressing interest
      // This prevents FK constraint violation: "express_interests_user_id_fkey"
      final profile = await getProfile(userId);
      if (profile == null) {
        debugPrint(
          'SupabaseService: Profile not found for user $userId, attempting to create',
        );
        await createProfile(userId);
      }

      // Try to create express interest record
      // If it fails due to unique constraint (already exists), update instead
      try {
        await _client.from('express_interests').insert({
          'user_id': userId,
          'job_id': jobId,
          'expressed_at': DateTime.now().toIso8601String(),
        });
        debugPrint('SupabaseService: Interest expressed successfully');
      } catch (insertError) {
        // If unique constraint violation, just return (already expressed)
        if (insertError.toString().contains('unique') ||
            insertError.toString().contains('duplicate')) {
          debugPrint(
            'SupabaseService: Interest already expressed for this job',
          );
          return;
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('SupabaseService: Error expressing interest: $e');
      rethrow;
    }
  }

  // Cancel express interest in a job
  static Future<void> cancelExpressInterest(String userId, String jobId) async {
    try {
      debugPrint(
        'SupabaseService: Canceling interest in job $jobId for user $userId',
      );
      await _client
          .from('express_interests')
          .delete()
          .eq('user_id', userId)
          .eq('job_id', jobId);
      debugPrint('SupabaseService: Interest canceled successfully');
    } catch (e) {
      debugPrint('SupabaseService: Error canceling interest: $e');
      rethrow;
    }
  }

  // Check if user has expressed interest in a job
  static Future<bool> hasExpressedInterest(String userId, String jobId) async {
    try {
      final response = await _client
          .from('express_interests')
          .select()
          .eq('user_id', userId)
          .eq('job_id', jobId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('SupabaseService: Error checking express interest: $e');
      return false;
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
    String? coverLetter, {
    String? resumeUrl,
    Map<String, dynamic>? profileSnapshot,
  }) async {
    try {
      debugPrint('SupabaseService: Applying for job $jobId with user $userId');

      // FIX: Check if profile exists before applying
      // This prevents FK constraint violation: "applications_user_id_fkey"
      final profile = await getProfile(userId);
      if (profile == null) {
        debugPrint(
          'SupabaseService: Profile not found for user $userId, attempting to create',
        );
        await createProfile(userId);
      }

      await _client.from('applications').insert({
        'user_id': userId,
        'job_id': jobId,
        'cover_letter': coverLetter,
        if (resumeUrl != null) 'resume_url': resumeUrl,
        if (profileSnapshot != null) 'profile_snapshot': profileSnapshot,
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
    await _client
        .from('applications')
        .update({'status': status})
        .eq('id', applicationId);
  }

  // ── Employer / reverse search ───────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getOpenCandidates({
    String? searchQuery,
    String? location,
    String? skill,
  }) async {
    var query = _client
        .from('profiles')
        .select('''
          id,
          full_name,
          headline,
          job_title,
          location,
          years_of_experience,
          profile_photo_url,
          bio,
          is_open_to_work,
          profile_visibility
        ''')
        .eq('is_open_to_work', true)
        .eq('profile_visibility', 'everyone');

    if (location != null && location.trim().isNotEmpty) {
      query = query.ilike('location', '%${location.trim()}%');
    }

    final response = await query
        .order('updated_at', ascending: false)
        .limit(40);
    var candidates = List<Map<String, dynamic>>.from(response);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      candidates = candidates.where((c) {
        final haystack = [
          c['full_name'] as String? ?? '',
          c['headline'] as String? ?? '',
          c['job_title'] as String? ?? '',
          c['bio'] as String? ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    if (skill != null && skill.trim().isNotEmpty) {
      final skillLower = skill.trim().toLowerCase();
      final filtered = <Map<String, dynamic>>[];
      for (final candidate in candidates) {
        final userId = candidate['id'] as String;
        final skills = await getUserSkillNames(userId);
        if (skills.any((s) => s.toLowerCase().contains(skillLower))) {
          filtered.add(candidate);
        }
      }
      candidates = filtered;
    }

    return candidates;
  }

  static Future<void> expressInterestInCandidate(
    String recruiterId,
    String candidateId, {
    String? message,
  }) async {
    try {
      await _client.from('candidate_interests').insert({
        'recruiter_id': recruiterId,
        'candidate_id': candidateId,
        'message':
            message ??
            'A recruiter is interested in your profile for an open role.',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SupabaseService: candidate_interests insert $e');
    }

    try {
      await _client.from('notifications').insert({
        'user_id': candidateId,
        'type': 'recruiter_interest',
        'title': 'Recruiter expressed interest',
        'body': message ?? 'A recruiter wants to connect about opportunities.',
        'data': {'recruiter_id': recruiterId},
        'is_read': false,
      });
    } catch (e) {
      debugPrint('SupabaseService: recruiter notification $e');
    }
  }

  static Future<bool> hasExpressedInterestInCandidate(
    String recruiterId,
    String candidateId,
  ) async {
    try {
      final row = await _client
          .from('candidate_interests')
          .select()
          .eq('recruiter_id', recruiterId)
          .eq('candidate_id', candidateId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isCurrentUserEmployer() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final profile = await getProfile(userId);
    if (profile == null) return false;
    return isRecruiterProfile(profile);
  }

  // Create a job (employer)
  static Future<Map<String, dynamic>> createJob(
    String userId,
    Map<String, dynamic> job,
  ) async {
    try {
      debugPrint('SupabaseService: Creating job for user $userId');

      final payload = {
        'poster_id': userId,
        'title': job['title'],
        'company_name': job['company_name'],
        'location': job['location'],
        'description': job['description'],
        'employment_type': job['employment_type'],
        'work_model': job['work_model'],
        'salary_min': job['salary_min'],
        'salary_max': job['salary_max'],
        'is_active': job['is_active'] ?? true,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('jobs')
          .insert(payload)
          .select()
          .maybeSingle();

      if (response == null) {
        debugPrint('SupabaseService: createJob returned null response');
        throw Exception('Failed to create job: empty response');
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: Error creating job: $e');
      rethrow;
    }
  }

  // Update a job
  static Future<void> updateJob(String jobId, Map<String, dynamic> data) async {
    await _client.from('jobs').update(data).eq('id', jobId);
  }

  // Delete a job
  static Future<void> deleteJob(String jobId) async {
    await _client.from('jobs').delete().eq('id', jobId);
  }

  // Get jobs posted by a specific poster
  static Future<List<Map<String, dynamic>>> getJobsByPoster(
    String posterId,
  ) async {
    try {
      final response = await _client
          .from('jobs')
          .select('''
            *,
            companies (
              id,
              name,
              logo_url
            )
          ''')
          .eq('poster_id', posterId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: getJobsByPoster $e');
      return [];
    }
  }

  // Upload a company logo to Supabase storage and return public URL
  static Future<String?> uploadCompanyLogo({
    required String posterId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      if (!['png', 'jpg', 'jpeg'].contains(ext)) {
        throw Exception('Unsupported image type');
      }

      final storagePath =
          'company_logos/$posterId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage
          .from('company_logos')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = _client.storage
          .from('company_logos')
          .getPublicUrl(storagePath);
      return url;
    } catch (e) {
      debugPrint('SupabaseService: uploadCompanyLogo $e');
      return null;
    }
  }
}
