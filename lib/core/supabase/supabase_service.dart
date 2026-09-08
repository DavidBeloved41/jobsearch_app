import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/router.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  static String describeSupabaseError(Object error) {
    if (error is PostgrestException) {
      return 'message=${error.message}; code=${error.code}; '
          'details=${error.details}; hint=${error.hint}';
    }
    return error.toString();
  }

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
          'id, full_name, headline, job_title, company_name, profile_photo_url, account_type',
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

  static const String authorizedAdminEmail = 'beloveddavid41@gmail.com';

  static String normalizeAccountType(Object? rawAccountType) {
    final accountType = (rawAccountType as String? ?? '').trim().toLowerCase();
    if (accountType == 'employer' || accountType == 'recruiter') {
      return 'employer';
    }
    if (accountType == 'admin' || accountType == 'administrator') {
      return 'admin';
    }
    if (accountType == 'job_seeker' ||
        accountType == 'job seeker' ||
        accountType == 'candidate' ||
        accountType == 'jobseeker') {
      return 'job_seeker';
    }
    // Unknown/unspecified account types should be explicit
    return 'unknown';
  }

  static bool isJobSeekerRole(Object? rawAccountType) {
    return normalizeAccountType(rawAccountType) == 'job_seeker';
  }

  static bool isEmailConfirmedAt(Object? emailConfirmedAt) {
    if (emailConfirmedAt == null) return false;
    if (emailConfirmedAt is DateTime) return true;
    if (emailConfirmedAt is String) {
      return emailConfirmedAt.trim().isNotEmpty;
    }
    return true;
  }

  static bool isEmailConfirmed(User? user) {
    return user != null && isEmailConfirmedAt(user.emailConfirmedAt);
  }

  static bool canAccessAuthenticatedApp({Session? session, User? user}) {
    return session != null && user != null && isEmailConfirmed(user);
  }

  static String maskEmail(String? email) {
    final trimmed = (email ?? '').trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return trimmed;
    }

    final parts = trimmed.split('@');
    final localPart = parts.first;
    final domain = parts.last;
    if (localPart.length <= 2) {
      return '${localPart.substring(0, 1)}***@$domain';
    }
    return '${localPart.substring(0, 2)}***@$domain';
  }

  static bool canApplyToJobs(Object? rawAccountType) {
    return isJobSeekerRole(rawAccountType);
  }

  static bool isApplicationAllowed({
    required Object? rawAccountType,
    required Object? emailConfirmedAt,
  }) {
    final normalizedType = normalizeAccountType(rawAccountType);
    if (normalizedType != 'job_seeker') return false;
    return isEmailConfirmedAt(emailConfirmedAt);
  }

  static String formatSalaryDisplay({
    num? min,
    num? max,
    String? currency,
    bool negotiable = false,
  }) {
    if (negotiable) return 'Negotiable';

    // Salary values are stored as numbers; SmartJob displays all salaries in
    // the Ghanaian market currency regardless of legacy stored currency text.
    const displayCurrency = 'GH₵';

    final minValue = min is num ? min.toDouble() : null;
    final maxValue = max is num ? max.toDouble() : null;

    if ((minValue == null || minValue <= 0) &&
        (maxValue == null || maxValue <= 0)) {
      return 'Salary not listed';
    }

    if (minValue != null && maxValue != null && minValue > 0 && maxValue > 0) {
      if (minValue == maxValue) {
        return '$displayCurrency${NumberFormat('#,###').format(minValue)}';
      }
      return '$displayCurrency${NumberFormat('#,###').format(minValue)} - $displayCurrency${NumberFormat('#,###').format(maxValue)}';
    }

    final singleValue = (minValue != null && minValue > 0)
        ? minValue
        : maxValue;
    if (singleValue == null || singleValue <= 0) {
      return 'Salary not listed';
    }
    return '$displayCurrency${NumberFormat('#,###').format(singleValue)}';
  }

  static bool isAuthorizedAdminEmail(String? email) {
    return email != null && email.trim().toLowerCase() == authorizedAdminEmail;
  }

  static bool isAuthorizedAdminUser({String? email, Object? accountType}) {
    return isAuthorizedAdminEmail(email) &&
        normalizeAccountType(accountType) == 'admin';
  }

  static bool isJobVisibleToJobSeekers({
    required bool isActive,
    String? status,
  }) {
    if (!isActive) return false;
    final normalizedStatus = (status ?? '').trim().toLowerCase();
    if (normalizedStatus.isEmpty) return true;
    return normalizedStatus == 'approved' || normalizedStatus == 'active';
  }

  static Future<bool> isAuthorizedAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final profile = await getProfile(user.id);
    return isAuthorizedAdminUser(
      email: user.email,
      accountType:
          profile?['account_type'] ?? user.userMetadata?['account_type'],
    );
  }

  static bool isRecruiterProfile(Map<String, dynamic> profile) {
    final accountType = normalizeAccountType(profile['account_type']);
    if (accountType == 'employer') {
      return true;
    }
    final headline = (profile['headline'] as String? ?? '').toLowerCase();
    return headline.contains('recruiter') ||
        headline.contains('talent acquisition') ||
        headline.contains('hiring manager');
  }

  static Future<String> getRoleRoute(String userId) async {
    final profile = await getProfile(userId);
    var rawAccountType = profile?['account_type'] as String?;

    // Primary source: profiles.account_type
    // Fallback: auth metadata account_type
    if (rawAccountType == null || rawAccountType.trim().isEmpty) {
      final user = _client.auth.currentUser;
      final metadataAccountType =
          user?.userMetadata?['account_type'] as String?;
      rawAccountType = metadataAccountType;
    }

    // If still no account type, default to job seeker home
    if (rawAccountType == null || rawAccountType.trim().isEmpty) {
      debugPrint(
        'SupabaseService.getRoleRoute: No account_type found for user $userId, defaulting to home',
      );
      return AppRoutes.home;
    }

    final accountType = normalizeAccountType(rawAccountType);
    switch (accountType) {
      case 'employer':
        debugPrint(
          'SupabaseService.getRoleRoute: User $userId is employer, routing to employer dashboard',
        );
        return AppRoutes.employerDashboard;
      case 'admin':
        debugPrint(
          'SupabaseService.getRoleRoute: User $userId is admin, routing to admin dashboard',
        );
        return AppRoutes.adminDashboard;
      case 'job_seeker':
      case 'unknown':
        debugPrint(
          'SupabaseService.getRoleRoute: User $userId has account_type=$accountType, routing to home',
        );
        return AppRoutes.home;
      default:
        debugPrint(
          'SupabaseService.getRoleRoute: Unknown account_type=$accountType for user $userId, defaulting to home',
        );
        return AppRoutes.home;
    }
  }

  static String roleLabel(String accountType) {
    switch (normalizeAccountType(accountType)) {
      case 'employer':
        return 'Employer';
      case 'admin':
        return 'Admin';
      case 'job_seeker':
        return 'Job seeker';
      default:
        return 'Unknown';
    }
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

  static Future<void> markMessagesDelivered(String senderId) async {
    try {
      await _client.rpc(
        'mark_messages_delivered',
        params: {'p_sender_id': senderId},
      );
    } catch (error) {
      debugPrint('SupabaseService: markMessagesDelivered: $error');
    }
  }

  static Future<void> markMessagesSeen(String senderId) async {
    try {
      await _client.rpc(
        'mark_messages_seen',
        params: {'p_sender_id': senderId},
      );
    } catch (error) {
      debugPrint('SupabaseService: markMessagesSeen: $error');
    }
  }

  static Future<int> getUnreadMessageCount(String userId) async {
    if (userId.trim().isEmpty || _client.auth.currentUser?.id != userId) {
      return 0;
    }
    final response = await _client
        .from('messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('is_read', false);
    return countUnreadMessages(
      List<Map<String, dynamic>>.from(response),
      userId,
    );
  }

  static int countUnreadMessages(
    Iterable<Map<String, dynamic>> messages,
    String userId,
  ) {
    return messages
        .where(
          (message) =>
              message['receiver_id'] == userId && message['is_read'] != true,
        )
        .length;
  }

  static String messageDeliveryStatus(Map<String, dynamic> message) {
    if (message['_pending'] == true) return 'Sending';
    if (message['seen_at'] != null) return 'Read';
    if (message['delivered_at'] != null) return 'Delivered';
    return 'Sent';
  }

  static Future<List<Map<String, dynamic>>> getConversationMessages(
    String userId,
    String partnerId,
  ) async {
    if (userId.trim().isEmpty || partnerId.trim().isEmpty) return [];
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('Your sign-in session is no longer valid.');
    }
    final sent = await _client
        .from('messages')
        .select()
        .eq('sender_id', userId)
        .eq('receiver_id', partnerId);
    final received = await _client
        .from('messages')
        .select()
        .eq('sender_id', partnerId)
        .eq('receiver_id', userId);
    final messages = [
      ...List<Map<String, dynamic>>.from(sent),
      ...List<Map<String, dynamic>>.from(received),
    ];
    messages.sort(
      (a, b) => (a['created_at'] as String? ?? '').compareTo(
        b['created_at'] as String? ?? '',
      ),
    );
    return messages;
  }

  static Future<Map<String, dynamic>?> getMessagingParticipant(
    String participantId,
  ) async {
    try {
      final response = await _client.rpc(
        'get_messaging_participant',
        params: {'participant_id': participantId},
      );
      if (response is List && response.isNotEmpty && response.first is Map) {
        return Map<String, dynamic>.from(response.first as Map);
      }
    } catch (e) {
      debugPrint('SupabaseService: getMessagingParticipant $e');
    }
    return null;
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
  static Future<List<Map<String, dynamic>>> _attachEmployerProfileData(
    List<Map<String, dynamic>> jobs,
  ) async {
    final enriched = <Map<String, dynamic>>[];
    for (final job in jobs) {
      final item = Map<String, dynamic>.from(job);
      final posterId = (item['poster_id'] as String?)?.trim();
      String? companyName;
      String? logoUrl;

      if (posterId != null && posterId.isNotEmpty) {
        try {
          final employerProfile = await getEmployerProfile(posterId);
          companyName =
              (employerProfile?['company_name'] as String?) ??
              (item['company_name'] as String?);
          logoUrl =
              (employerProfile?['logo_url'] as String?) ??
              (item['company_logo_url'] as String?);

          if (companyName != null && companyName.trim().isNotEmpty) {
            item['company_name'] = companyName.trim();
          }
          if (logoUrl != null && logoUrl.trim().isNotEmpty) {
            item['company_logo_url'] = logoUrl.trim();
          }

          if (employerProfile != null) {
            final normalizedCompanyName =
                ((employerProfile['company_name'] as String?) ??
                        companyName ??
                        '')
                    .trim();
            final normalizedLogoUrl =
                ((employerProfile['logo_url'] as String?) ?? logoUrl ?? '')
                    .trim();
            item['companies'] = {
              'name': normalizedCompanyName,
              'logo_url': normalizedLogoUrl,
              'industry': employerProfile['industry'],
              'average_rating': employerProfile['average_rating'],
            };
          }
        } catch (_) {
          debugPrint(
            'SupabaseService: job employer enrichment failed for $posterId',
          );
        }
      }

      if (companyName == null || companyName.trim().isEmpty) {
        companyName =
            (item['companies'] as Map<String, dynamic>?)?['name'] as String? ??
            (item['company_name'] as String?) ??
            'Company';
      }
      if (logoUrl == null || logoUrl.trim().isEmpty) {
        logoUrl =
            (item['companies'] as Map<String, dynamic>?)?['logo_url']
                as String? ??
            (item['company_logo_url'] as String?);
      }

      item['company_name'] ??= companyName;
      item['company_logo_url'] ??= logoUrl;
      item['companies'] ??= {'name': companyName, 'logo_url': logoUrl};

      enriched.add(item);
    }

    return enriched;
  }

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
          *
        ''')
        .eq('is_active', true)
        .eq('approval_status', 'approved');

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
    jobs = await _attachEmployerProfileData(jobs);

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
              job_title,
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
          .select('id, full_name, job_title, profile_photo_url, account_type')
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

  static Future<Map<String, dynamic>?> getEmployerProfile(String userId) async {
    debugPrint(
      '[EMPLOYER PROFILE] Query userId=$userId table=employer_profiles',
    );
    final response = await _client
        .from('employer_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    debugPrint(
      '[EMPLOYER PROFILE] Query result=${response == null ? 'missing' : 'found'}',
    );
    return response;
  }

  static Future<Map<String, dynamic>?> getJobSeekerProfile(
    String userId,
  ) async {
    debugPrint(
      '[JOB SEEKER PROFILE] Query userId=$userId table=job_seeker_profiles',
    );
    final response = await _client
        .from('job_seeker_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    debugPrint(
      '[JOB SEEKER PROFILE] Query result=${response == null ? 'missing' : 'found'}',
    );
    return response;
  }

  static Future<Map<String, dynamic>?> getJobSeekerProfileContext(
    String userId,
  ) async {
    final profile = await getProfile(userId);
    final preferences = await getJobSeekerProfile(userId);
    if (profile == null) return null;
    return {...profile, ...?preferences};
  }

  static Future<Map<String, dynamic>> upsertJobSeekerProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[JOB SEEKER PROFILE] UPSERT userId=$userId fields=${data.keys.join(', ')}',
    );
    final response = await _client
        .from('job_seeker_profiles')
        .upsert({'user_id': userId, ...data}, onConflict: 'user_id')
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> createEmployerProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[EMPLOYER PROFILE] INSERT userId=$userId fields=${data.keys.join(', ')}',
    );
    final response = await _client
        .from('employer_profiles')
        .insert({'user_id': userId, ...data})
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  static Future<Map<String, dynamic>> updateEmployerProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    debugPrint(
      '[EMPLOYER PROFILE] UPDATE userId=$userId fields=${data.keys.join(', ')}',
    );
    final response = await _client
        .from('employer_profiles')
        .upsert({'user_id': userId, ...data}, onConflict: 'user_id')
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  // Create user profile (called during signup or if missing).
  // Keep the profile role normalized to the app's supported values. Auth email
  // remains authoritative in auth.users rather than being duplicated here.
  static Future<void> createProfile(
    String userId, {
    String? email,
    String? fullName,
    String? accountType,
  }) async {
    debugPrint('SupabaseService: Creating profile for user $userId');
    try {
      final normalizedAccountType = accountType != null
          ? normalizeAccountType(accountType)
          : 'job_seeker';
      await _client.from('profiles').insert({
        'id': userId,
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
        'account_type': normalizedAccountType,
        'created_at': DateTime.now().toIso8601String(),
        'is_open_to_work': true,
      });
      debugPrint(
        'SupabaseService: Profile created successfully for user $userId with account_type=$normalizedAccountType',
      );
    } catch (e) {
      debugPrint(
        'SupabaseService: Error creating profile for user $userId: $e',
      );
      // Auth refresh and signup can race; an existing row means the profile
      // was created successfully by the other path.
      final existingProfile = await getProfile(userId);
      if (existingProfile != null) return;
      rethrow;
    }
  }

  // Update user profile
  static Future<void> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final sanitizedData = <String, dynamic>{...data};

      if (sanitizedData.containsKey('account_type')) {
        sanitizedData['account_type'] = normalizeAccountType(
          sanitizedData['account_type'],
        );
      }

      final response = await _client
          .from('profiles')
          .update(sanitizedData)
          .eq('id', userId)
          .select();
      final rows = response as List<dynamic>?;
      if (rows == null || rows.isEmpty) {
        debugPrint(
          'SupabaseService: updateProfile found no profile, creating one',
        );
        await createProfile(
          userId,
          email: _client.auth.currentUser?.email,
          fullName:
              _client.auth.currentUser?.userMetadata?['full_name'] as String?,
          accountType: sanitizedData['account_type'] ?? 'job_seeker',
        );
      }
    } catch (e) {
      debugPrint('SupabaseService: updateProfile error=$e');
      rethrow;
    }
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
    int? matchScore,
    Map<String, dynamic>? profileSnapshot,
  }) async {
    try {
      debugPrint('SupabaseService: Applying for job $jobId with user $userId');

      final currentUser = _client.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        throw StateError('Your sign-in session is no longer valid.');
      }

      final profile = await getProfile(userId);
      final accountType = normalizeAccountType(
        profile?['account_type'] ??
            _client.auth.currentUser?.userMetadata?['account_type'],
      );
      if (!isApplicationAllowed(
        rawAccountType: accountType,
        emailConfirmedAt: currentUser.emailConfirmedAt,
      )) {
        if (!isEmailConfirmed(currentUser)) {
          throw StateError('Please verify your email before applying.');
        }
        throw StateError('Only job seekers can apply for jobs.');
      }

      // Check if user has already applied to this job
      final existingApplication = await _client
          .from('applications')
          .select('id')
          .eq('user_id', userId)
          .eq('job_id', jobId)
          .limit(1)
          .maybeSingle();

      if (existingApplication != null) {
        throw StateError('You have already applied for this job.');
      }

      final jobRow = await _client
          .from('jobs')
          .select('id, is_active, approval_status, title')
          .eq('id', jobId)
          .maybeSingle();
      if (jobRow == null) {
        throw StateError('Job not found.');
      }
      final isActive = jobRow['is_active'] as bool? ?? false;
      final approvalStatus =
          (jobRow['approval_status'] as String?) ?? 'pending';
      final jobTitle = jobRow['title'] as String? ?? 'job';

      if (approvalStatus != 'approved') {
        throw StateError('This job is not currently accepting applications.');
      }

      if (!isJobVisibleToJobSeekers(isActive: isActive)) {
        throw StateError('This job is not available for applications.');
      }

      if (profile == null) {
        debugPrint(
          'SupabaseService: Profile not found for user $userId, attempting to create',
        );
        await createProfile(userId);
      }

      final applicationData = {
        'user_id': userId,
        'job_id': jobId,
        'cover_letter': coverLetter,
        if (matchScore != null) 'match_score': matchScore,
        'status': 'applied',
        'applied_at': DateTime.now().toIso8601String(),
      };
      debugPrint(
        '[EASY APPLY] Inserting application for job "$jobTitle" with fields: ${applicationData.keys.join(', ')}',
      );
      if (profileSnapshot != null) {
        debugPrint(
          '[EASY APPLY] Profile snapshot keys=${profileSnapshot.keys.join(', ')} (not persisted)',
        );
      }
      final insertedApplication = await _client
          .from('applications')
          .insert(applicationData)
          .select('id, user_id, job_id')
          .single();
      if (insertedApplication['id'] == null ||
          insertedApplication['user_id'] != userId ||
          insertedApplication['job_id'] != jobId) {
        throw StateError('Application creation could not be verified.');
      }
      debugPrint(
        '[EASY APPLY] Application submitted successfully for jobId: $jobId, userId: $userId',
      );
    } catch (e) {
      debugPrint(
        'SupabaseService: Error applying for job: ${describeSupabaseError(e)}',
      );
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

  static Future<Map<String, dynamic>> updateApplicationStatus(
    String applicationId,
    String status, {
    required String employerId,
  }) async {
    if (_client.auth.currentUser?.id != employerId) {
      throw StateError('Your sign-in session is no longer valid.');
    }
    if (!isValidApplicationStatus(status)) {
      throw ArgumentError('Unsupported application status.');
    }
    debugPrint(
      '[EMPLOYER STATUS] employerId=$employerId applicationId=$applicationId requestedStatus=$status',
    );
    final response = await _client.rpc(
      'employer_dashboard_update_application_status',
      params: {'p_application_id': applicationId, 'p_status': status},
    );
    debugPrint('[EMPLOYER STATUS] rpcResponse=$response');
    final rows = response is List ? response : [response];
    if (rows.isEmpty || rows.first is! Map) {
      throw StateError('Application status was not updated.');
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  static bool isValidApplicationStatus(String status) {
    return const {
      'applied',
      'reviewing',
      'interviewing',
      'offered',
      'rejected',
      'declined',
    }.contains(status.trim().toLowerCase());
  }

  static bool canMessageBetweenRoles(String senderRole, String receiverRole) {
    const allowed = {'employer', 'job_seeker'};
    return allowed.contains(normalizeAccountType(senderRole)) &&
        allowed.contains(normalizeAccountType(receiverRole)) &&
        normalizeAccountType(senderRole) != normalizeAccountType(receiverRole);
  }

  static Future<Map<String, int>> getApplicationStatusCountsForEmployer(
    String employerId,
  ) async {
    final jobs = await _client
        .from('jobs')
        .select('id')
        .eq('poster_id', employerId);
    final jobIds = (jobs as List)
        .map((job) => job['id']?.toString())
        .whereType<String>()
        .toList();
    final counts = {
      'all': 0,
      'applied': 0,
      'interviewing': 0,
      'offered': 0,
      'declined': 0,
    };
    if (jobIds.isEmpty) return counts;
    final applications = await _client
        .from('applications')
        .select('status')
        .inFilter('job_id', jobIds);
    for (final application in applications as List) {
      final status = application['status']?.toString() ?? 'applied';
      counts['all'] = counts['all']! + 1;
      if (counts.containsKey(status)) counts[status] = counts[status]! + 1;
    }
    return counts;
  }

  static Future<List<Map<String, dynamic>>> getApplicationsForEmployer(
    String employerId,
  ) async {
    final jobs = await _client
        .from('jobs')
        .select('id')
        .eq('poster_id', employerId);
    final jobIds = (jobs as List)
        .map((job) => job['id']?.toString())
        .whereType<String>()
        .toList();
    if (jobIds.isEmpty) return [];
    final response = await _client
        .from('applications')
        .select('''
          id,
          user_id,
          job_id,
          cover_letter,
          match_score,
          status,
          applied_at,
          jobs (
            id,
            title,
            poster_id
          ),
          profiles:user_id (
            id,
            full_name,
            job_title,
            location,
            bio,
            profile_photo_url,
            resume_url
          )
        ''')
        .inFilter('job_id', jobIds)
        .order('applied_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != senderId) {
      throw StateError('Your sign-in session is no longer valid.');
    }
    debugPrint(
      '[EMPLOYER MESSAGE] senderId=$senderId receiverId=$receiverId operation=employer_dashboard_send_message',
    );
    final response = await _client.rpc(
      'employer_dashboard_send_message',
      params: {'p_receiver_id': receiverId, 'p_content': content},
    );
    debugPrint('[EMPLOYER MESSAGE] rpcResponse=$response');
    if (response is! Map) {
      throw StateError('Message creation could not be verified.');
    }
    final message = Map<String, dynamic>.from(response);
    if (message['sender_id'] != senderId ||
        message['receiver_id'] != receiverId) {
      throw StateError('Message creation could not be verified.');
    }
    return message;
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

    // Notification creation is server-side via the candidate_interests trigger.
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
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;

      final Map<String, dynamic> payload = {
        'poster_id': currentUserId,
        'title': job['title'],
        'location': job['location'],
        'description': job['description'],
        'employment_type': job['employment_type'],
        'work_model': job['work_model'],
        'salary_min': job['salary_min'],
        'salary_max': job['salary_max'],
        'salary_currency': 'GHS',
        'approval_status': 'pending',
        'is_active': false,
      };

      debugPrint('SupabaseService: jobs insert payload: $payload');

      final response = await _client
          .from('jobs')
          .insert(payload)
          .select()
          .maybeSingle();

      if (response == null) {
        debugPrint('SupabaseService: createJob returned null response');
        throw Exception('Failed to create job: empty response');
      }

      final createdJob = Map<String, dynamic>.from(response);
      final createdJobId = createdJob['id']?.toString();
      if (createdJobId == null || createdJobId.isEmpty) {
        throw StateError('Job was created without a database ID.');
      }
      final persistedJob = await _client
          .from('jobs')
          .select('id, approval_status, is_active')
          .eq('id', createdJobId)
          .maybeSingle();
      if (persistedJob == null) {
        throw StateError('Job creation could not be verified.');
      }
      if (persistedJob['approval_status'] != 'pending' ||
          persistedJob['is_active'] != false) {
        throw StateError('New jobs must start pending and inactive.');
      }
      debugPrint('SupabaseService: jobs insert returned row: $createdJob');
      return createdJob;
    } on PostgrestException catch (error) {
      debugPrint('SupabaseService: createJob PostgREST error');
      debugPrint('message: ${error.message}');
      debugPrint('code: ${error.code}');
      debugPrint('details: ${error.details}');
      debugPrint('hint: ${error.hint}');
      rethrow;
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
            *
          ''')
          .eq('poster_id', posterId)
          .order('created_at', ascending: false);
      return await _attachEmployerProfileData(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('SupabaseService: getJobsByPoster $e');
      return [];
    }
  }

  // Get total count of applicants across all jobs for a poster
  static Future<int> getApplicantCountForPoster(String posterId) async {
    try {
      // Fetch job ids posted by this poster
      final jobs = await _client
          .from('jobs')
          .select('id')
          .eq('poster_id', posterId);
      final jobIds = (jobs as List).map((j) => j['id'] as String).toList();
      if (jobIds.isEmpty) return 0;

      final inClause = jobIds.map((id) => "'$id'").join(',');
      final apps = await _client
          .from('applications')
          .select('id')
          .filter('job_id', 'in', '($inClause)');
      return (apps as List).length;
    } catch (e) {
      debugPrint('SupabaseService: getApplicantCountForPoster $e');
      return 0;
    }
  }

  // Get count of active jobs for a poster
  static Future<int> getActiveJobCountForPoster(String posterId) async {
    try {
      final response = await _client
          .from('jobs')
          .select('id')
          .eq('poster_id', posterId)
          .eq('is_active', true);
      return (response as List).length;
    } catch (e) {
      debugPrint('SupabaseService: getActiveJobCountForPoster $e');
      return 0;
    }
  }

  // Get recent applications for employer dashboard
  static Future<List<Map<String, dynamic>>> getRecentApplicationsForPoster(
    String posterId, {
    int limit = 10,
  }) async {
    try {
      final jobs = await _client
          .from('jobs')
          .select('id')
          .eq('poster_id', posterId);
      final jobIds = (jobs as List).map((j) => j['id'] as String).toList();
      if (jobIds.isEmpty) return [];

      // Use PostgREST's in filter with proper syntax
      final response = await _client
          .from('applications')
          .select('''
            id,
            applied_at,
            status,
            job_id,
            user_id,
            cover_letter,
            jobs (
              id,
              title
            ),
            profiles:user_id (
              id,
              full_name,
              job_title
            )
          ''')
          .inFilter('job_id', jobIds)
          .order('applied_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: getRecentApplicationsForPoster error: $e');
      rethrow;
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

  // ── Admin Management Methods ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAllJobsForAdmin() async {
    try {
      debugPrint('SupabaseService: Querying getAllJobsForAdmin');
      // Query jobs WITHOUT join first (to avoid join failures)
      final response = await _client
          .from('jobs')
          .select('''
            id,
            title,
            description,
            location,
            work_model,
            employment_type,
            experience_level,
            salary_min,
            salary_max,
            salary_currency,
            approval_status,
            is_active,
            created_at,
            updated_at,
            poster_id,
            approved_at,
            approved_by,
            rejection_reason
          ''')
          .order('created_at', ascending: false);

      final jobs = List<Map<String, dynamic>>.from(response);
      debugPrint(
        'SupabaseService: getAllJobsForAdmin returned ${jobs.length} jobs',
      );

      // Enrich with employer profile data separately
      for (final job in jobs) {
        final posterId = job['poster_id'] as String?;
        if (posterId != null && posterId.isNotEmpty) {
          try {
            final profile = await getProfile(posterId);
            if (profile != null) {
              job['employer'] = {
                'id': profile['id'],
                'full_name': profile['full_name'],
                'account_type': profile['account_type'],
              };
            }
          } catch (e) {
            debugPrint(
              'SupabaseService: Failed to fetch employer profile for $posterId: $e',
            );
          }
        }
      }

      return jobs;
    } catch (e) {
      debugPrint('SupabaseService: getAllJobsForAdmin ERROR: $e');
      rethrow; // Let caller see the actual error
    }
  }

  static Future<List<Map<String, dynamic>>> getJobsByApprovalStatus(
    String status,
  ) async {
    try {
      debugPrint('SupabaseService: Querying jobs by approval_status=$status');
      final response = await _client
          .from('jobs')
          .select('''
            id,
            title,
            location,
            work_model,
            employment_type,
            salary_min,
            salary_max,
            approval_status,
            is_active,
            created_at,
            poster_id
          ''')
          .eq('approval_status', status)
          .order('created_at', ascending: false);

      final jobs = List<Map<String, dynamic>>.from(response);
      debugPrint(
        'SupabaseService: getJobsByApprovalStatus returned ${jobs.length} jobs',
      );

      // Enrich with employer profile data
      for (final job in jobs) {
        final posterId = job['poster_id'] as String?;
        if (posterId != null && posterId.isNotEmpty) {
          try {
            final profile = await getProfile(posterId);
            if (profile != null) {
              job['employer'] = {
                'id': profile['id'],
                'full_name': profile['full_name'],
              };
            }
          } catch (e) {
            debugPrint(
              'SupabaseService: Failed to fetch employer profile for $posterId: $e',
            );
          }
        }
      }

      return jobs;
    } catch (e) {
      debugPrint('SupabaseService: getJobsByApprovalStatus($status) ERROR: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getJobForReview(String jobId) async {
    try {
      debugPrint('SupabaseService: Querying job for review: $jobId');
      final response = await _client
          .from('jobs')
          .select('*')
          .eq('id', jobId)
          .maybeSingle();

      if (response == null) {
        debugPrint('SupabaseService: Job not found: $jobId');
        return null;
      }

      final job = Map<String, dynamic>.from(response);

      // Fetch employer profile
      final posterId = job['poster_id'] as String?;
      if (posterId != null && posterId.isNotEmpty) {
        try {
          final profile = await getProfile(posterId);
          if (profile != null) {
            job['employer'] = {
              'id': profile['id'],
              'full_name': profile['full_name'],
              'account_type': profile['account_type'],
            };
          }
        } catch (e) {
          debugPrint(
            'SupabaseService: Failed to fetch employer profile for $posterId: $e',
          );
        }
      }

      // Fetch applications for this job
      try {
        final apps = await _client
            .from('applications')
            .select('id, user_id, status, applied_at')
            .eq('job_id', jobId);
        job['applications'] = List<Map<String, dynamic>>.from(apps);
      } catch (e) {
        debugPrint(
          'SupabaseService: Failed to fetch applications for job $jobId: $e',
        );
        job['applications'] = [];
      }

      return job;
    } catch (e) {
      debugPrint('SupabaseService: getJobForReview ERROR: $e');
      rethrow;
    }
  }

  static Future<void> approveJob(String jobId, String approvedByUserId) async {
    try {
      await _client
          .from('jobs')
          .update({
            'approval_status': 'approved',
            'is_active': true,
            'approved_at': DateTime.now().toIso8601String(),
            'approved_by': approvedByUserId,
            'rejection_reason': null,
          })
          .eq('id', jobId);
      debugPrint('SupabaseService: Job $jobId approved');
    } catch (e) {
      debugPrint('SupabaseService: approveJob error $e');
      rethrow;
    }
  }

  static Future<void> rejectJob(String jobId, String rejectionReason) async {
    try {
      await _client
          .from('jobs')
          .update({
            'approval_status': 'rejected',
            'is_active': false,
            'rejection_reason': rejectionReason,
          })
          .eq('id', jobId);
      debugPrint('SupabaseService: Job $jobId rejected');
    } catch (e) {
      debugPrint('SupabaseService: rejectJob error $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser != null && isAuthorizedAdminEmail(currentUser.email)) {
        try {
          final response = await _client.rpc('get_admin_user_directory');
          if (response is List) {
            return List<Map<String, dynamic>>.from(response);
          }
        } catch (e) {
          debugPrint('SupabaseService: get_admin_user_directory fallback $e');
        }
      }

      final response = await _client
          .from('profiles')
          .select('id, full_name, account_type, created_at')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: getAllProfiles $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllApplications() async {
    try {
      final response = await _client
          .from('applications')
          .select('''
            id,
            user_id,
            job_id,
            status,
            cover_letter,
            match_score,
            applied_at,
            updated_at,
            profiles!applications_user_id_fkey (
              id,
              full_name,
              job_title
            ),
            jobs (
              id,
              title
            )
          ''')
          .order('applied_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseService: getAllApplications $e');
      rethrow;
    }
  }
}
