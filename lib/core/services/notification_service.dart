import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/match_score_service.dart';
import '../supabase/supabase_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const _notifiedJobsBox = 'notified_jobs';
  static const _highMatchThreshold = 75;

  static Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> checkHighMatchJobs({
    required List<Map<String, dynamic>> jobs,
    required List<String> userSkillNames,
    int? userYearsExperience,
  }) async {
    await initialize();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await SupabaseService.getProfile(user.id);
    if (profile?['notify_job_alerts'] == false) return;

    final box = await Hive.openBox(_notifiedJobsBox);
    final notified = <String>{
      ...box.keys.map((k) => k.toString()),
    };

    var sentThisSession = 0;
    const maxPerSession = 3;

    for (final job in jobs) {
      if (sentThisSession >= maxPerSession) break;

      final jobId = job['id'] as String? ?? '';
      if (jobId.isEmpty || notified.contains(jobId)) continue;

      final score = MatchScoreService.calculate(
        job: job,
        userSkillNames: userSkillNames,
        userYearsExperience: userYearsExperience,
      );

      if (score < _highMatchThreshold) continue;

      final title = job['title'] as String? ?? 'New job match';
      final company =
          (job['companies'] as Map<String, dynamic>?)?['name'] ?? '';

      await _showNotification(
        id: jobId.hashCode,
        title: 'High match job · $score%',
        body: company.isNotEmpty ? '$title at $company' : title,
      );

      await box.put(jobId, DateTime.now().toIso8601String());
      await _insertInAppNotification(user.id, title, company, score, jobId);
      sentThisSession++;
    }
  }

  static Future<void> _insertInAppNotification(
    String userId,
    String jobTitle,
    String company,
    int score,
    String jobId,
  ) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'type': 'job_match',
        'title': 'High match · $score%',
        'body': company.isNotEmpty
            ? '$jobTitle at $company'
            : jobTitle,
        'data': {'job_id': jobId, 'match_score': score},
        'is_read': false,
      });
    } catch (e) {
      debugPrint('NotificationService: in-app insert $e');
    }
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'high_match_jobs',
      'Job match alerts',
      channelDescription: 'Alerts for jobs that match your profile',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _plugin.show(id, title, body, details);
  }
}
