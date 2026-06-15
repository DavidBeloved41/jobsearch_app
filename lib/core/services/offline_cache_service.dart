import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_service.dart';

class OfflineCacheService {
  static const _boxName = 'offline_cache';
  static const _jobsKey = 'jobs_feed';
  static const _savedJobsKey = 'saved_jobs';
  static const _profilePrefix = 'profile_';
  static const _resumeDraftKey = 'resume_draft';
  static const _cachedAtKey = 'jobs_cached_at';
  static const _pendingApplicationsKey = 'pending_applications';
  static const _pendingProfileUpdatesKey = 'pending_profile_updates';
  static const _applicationsPrefix = 'applications_';
  static const _pendingMessagesKey = 'pending_messages';
  static const _conversationsPrefix = 'conversations_';

  static Future<Box> _box() => Hive.openBox(_boxName);

  static Future<void> cacheJobs(List<Map<String, dynamic>> jobs) async {
    try {
      final box = await _box();
      await box.put(_jobsKey, jsonEncode(jobs));
      await box.put(_cachedAtKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('OfflineCacheService: cacheJobs $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedJobs() async {
    try {
      final box = await _box();
      final raw = box.get(_jobsKey) as String?;
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('OfflineCacheService: getCachedJobs $e');
      return null;
    }
  }

  static Future<DateTime?> getJobsCachedAt() async {
    try {
      final box = await _box();
      final raw = box.get(_cachedAtKey) as String?;
      if (raw == null) return null;
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheSavedJobs(List<Map<String, dynamic>> saved) async {
    try {
      final box = await _box();
      await box.put(_savedJobsKey, jsonEncode(saved));
    } catch (e) {
      debugPrint('OfflineCacheService: cacheSavedJobs $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedSavedJobs() async {
    try {
      final box = await _box();
      final raw = box.get(_savedJobsKey) as String?;
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheProfile(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    try {
      final box = await _box();
      await box.put('$_profilePrefix$userId', jsonEncode(profile));
    } catch (e) {
      debugPrint('OfflineCacheService: cacheProfile $e');
    }
  }

  static Future<Map<String, dynamic>?> getCachedProfile(String userId) async {
    try {
      final box = await _box();
      final raw = box.get('$_profilePrefix$userId') as String?;
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveResumeDraft(String text) async {
    final box = await _box();
    await box.put(_resumeDraftKey, text);
  }

  static Future<String?> getResumeDraft() async {
    final box = await _box();
    return box.get(_resumeDraftKey) as String?;
  }

  static Future<void> clearResumeDraft() async {
    final box = await _box();
    await box.delete(_resumeDraftKey);
  }

  static Future<void> queueApplication({
    required String userId,
    required String jobId,
    String? coverLetter,
    String? resumeUrl,
  }) async {
    final box = await _box();
    final raw = box.get(_pendingApplicationsKey) as String?;
    final list = raw != null
        ? List<Map<String, dynamic>>.from(jsonDecode(raw) as List)
        : <Map<String, dynamic>>[];

    list.removeWhere(
      (item) => item['user_id'] == userId && item['job_id'] == jobId,
    );
    list.add({
      'user_id': userId,
      'job_id': jobId,
      'cover_letter': coverLetter,
      'resume_url': resumeUrl,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await box.put(_pendingApplicationsKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getPendingApplications() async {
    final box = await _box();
    final raw = box.get(_pendingApplicationsKey) as String?;
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
  }

  static Future<void> removePendingApplication(String userId, String jobId) async {
    final box = await _box();
    final raw = box.get(_pendingApplicationsKey) as String?;
    if (raw == null) return;
    final list = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    list.removeWhere(
      (item) => item['user_id'] == userId && item['job_id'] == jobId,
    );
    await box.put(_pendingApplicationsKey, jsonEncode(list));
  }

  static Future<int> getPendingApplicationCount() async {
    return (await getPendingApplications()).length;
  }

  static Future<void> queueProfileUpdate(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final box = await _box();
    final raw = box.get(_pendingProfileUpdatesKey) as String?;
    final map = raw != null
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : <String, dynamic>{};

    final existing = Map<String, dynamic>.from(
      map[userId] as Map? ?? {},
    );
    existing.addAll(data);
    map[userId] = existing;
    await box.put(_pendingProfileUpdatesKey, jsonEncode(map));
  }

  static Future<Map<String, dynamic>?> getPendingProfileUpdate(
    String userId,
  ) async {
    final box = await _box();
    final raw = box.get(_pendingProfileUpdatesKey) as String?;
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final update = map[userId];
    if (update == null) return null;
    return Map<String, dynamic>.from(update as Map);
  }

  static Future<void> clearPendingProfileUpdate(String userId) async {
    final box = await _box();
    final raw = box.get(_pendingProfileUpdatesKey) as String?;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map.remove(userId);
    await box.put(_pendingProfileUpdatesKey, jsonEncode(map));
  }

  static Future<void> cacheApplications(
    String userId,
    List<Map<String, dynamic>> applications,
  ) async {
    try {
      final box = await _box();
      await box.put(
        '$_applicationsPrefix$userId',
        jsonEncode(applications),
      );
    } catch (e) {
      debugPrint('OfflineCacheService: cacheApplications $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedApplications(
    String userId,
  ) async {
    try {
      final box = await _box();
      final raw = box.get('$_applicationsPrefix$userId') as String?;
      if (raw == null) return null;
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheConversations(
    String userId,
    List<Map<String, dynamic>> conversations,
  ) async {
    try {
      final box = await _box();
      await box.put(
        '$_conversationsPrefix$userId',
        jsonEncode(conversations),
      );
    } catch (e) {
      debugPrint('OfflineCacheService: cacheConversations $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedConversations(
    String userId,
  ) async {
    try {
      final box = await _box();
      final raw = box.get('$_conversationsPrefix$userId') as String?;
      if (raw == null) return null;
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    } catch (e) {
      return null;
    }
  }

  static Future<void> queueMessage({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final box = await _box();
    final raw = box.get(_pendingMessagesKey) as String?;
    final list = raw != null
        ? List<Map<String, dynamic>>.from(jsonDecode(raw) as List)
        : <Map<String, dynamic>>[];
    list.add({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await box.put(_pendingMessagesKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final box = await _box();
    final raw = box.get(_pendingMessagesKey) as String?;
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
  }

  static Future<void> clearPendingMessages() async {
    final box = await _box();
    await box.delete(_pendingMessagesKey);
  }

  static Future<void> removePendingMessage(int index) async {
    final box = await _box();
    final raw = box.get(_pendingMessagesKey) as String?;
    if (raw == null) return;
    final list = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await box.put(_pendingMessagesKey, jsonEncode(list));
    }
  }

  static Future<void> setPendingMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final box = await _box();
    if (messages.isEmpty) {
      await box.delete(_pendingMessagesKey);
    } else {
      await box.put(_pendingMessagesKey, jsonEncode(messages));
    }
  }
}

class OfflineSyncService {
  static Future<int> syncPendingChanges() async {
    var synced = 0;

    final pendingApps = await OfflineCacheService.getPendingApplications();
    for (final item in List<Map<String, dynamic>>.from(pendingApps)) {
      final userId = item['user_id'] as String? ?? '';
      final jobId = item['job_id'] as String? ?? '';
      if (userId.isEmpty || jobId.isEmpty) continue;

      try {
        await SupabaseService.applyForJob(
          userId,
          jobId,
          item['cover_letter'] as String?,
          resumeUrl: item['resume_url'] as String?,
        );
        await OfflineCacheService.removePendingApplication(userId, jobId);
        synced++;
      } catch (e) {
        debugPrint('OfflineSyncService: application sync failed $e');
      }
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final pendingProfile =
          await OfflineCacheService.getPendingProfileUpdate(user.id);
      if (pendingProfile != null && pendingProfile.isNotEmpty) {
        try {
          await SupabaseService.updateProfile(user.id, pendingProfile);
          await OfflineCacheService.clearPendingProfileUpdate(user.id);
          synced++;
        } catch (e) {
          debugPrint('OfflineSyncService: profile sync failed $e');
        }
      }

      final draft = await OfflineCacheService.getResumeDraft();
      if (draft != null && draft.isNotEmpty) {
        try {
          await SupabaseService.updateProfile(user.id, {
            'resume_draft': draft,
            'updated_at': DateTime.now().toIso8601String(),
          });
          synced++;
        } catch (e) {
          debugPrint('OfflineSyncService: resume draft sync optional $e');
        }
      }
    }

    final pendingMessages =
        await OfflineCacheService.getPendingMessages();
    final remaining = <Map<String, dynamic>>[];
    for (final msg in pendingMessages) {
      try {
        await Supabase.instance.client.from('messages').insert({
          'sender_id': msg['sender_id'],
          'receiver_id': msg['receiver_id'],
          'content': msg['content'],
        });
        synced++;
      } catch (e) {
        debugPrint('OfflineSyncService: message sync failed $e');
        remaining.add(msg);
      }
    }
    if (remaining.length != pendingMessages.length) {
      await OfflineCacheService.setPendingMessages(remaining);
    }

    return synced;
  }
}
