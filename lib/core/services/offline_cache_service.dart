import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineCacheService {
  static const _boxName = 'offline_cache';
  static const _jobsKey = 'jobs_feed';
  static const _savedJobsKey = 'saved_jobs';
  static const _profilePrefix = 'profile_';
  static const _resumeDraftKey = 'resume_draft';
  static const _cachedAtKey = 'jobs_cached_at';

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
}
