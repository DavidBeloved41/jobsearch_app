import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_service.dart';

enum CloudSource { googleDrive, dropbox, iCloud, device }

class CloudDocumentService {
  static const _allowedExtensions = ['pdf', 'doc', 'docx'];

  /// Opens the native file picker (includes Google Drive / iCloud on mobile).
  static Future<({Uint8List bytes, String fileName, CloudSource source})?>
  pickFromCloudPicker(CloudSource source) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      if (file.bytes == null || file.size > 5 * 1024 * 1024) return null;
      return (bytes: file.bytes!, fileName: file.name, source: source);
    } catch (e) {
      debugPrint('CloudDocumentService: pick $e');
      return null;
    }
  }

  /// Downloads a public/share link (Google Drive or Dropbox).
  static Future<({Uint8List bytes, String fileName})?> importFromShareUrl(
    String url,
  ) async {
    final downloadUrl = _normalizeShareUrl(url.trim());
    if (downloadUrl == null) return null;

    try {
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length > 5 * 1024 * 1024) return null;

      final fileName = _fileNameFromUrl(url) ?? 'resume.pdf';
      return (bytes: response.bodyBytes, fileName: fileName);
    } catch (e) {
      debugPrint('CloudDocumentService: importFromShareUrl $e');
      return null;
    }
  }

  static String? _normalizeShareUrl(String url) {
    if (url.contains('drive.google.com')) {
      final idMatch =
          RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(url) ??
          RegExp(r'id=([a-zA-Z0-9_-]+)').firstMatch(url);
      if (idMatch != null) {
        return 'https://drive.google.com/uc?export=download&id=${idMatch.group(1)}';
      }
    }
    if (url.contains('dropbox.com')) {
      return url
          .replaceFirst('www.dropbox.com', 'dl.dropboxusercontent.com')
          .replaceAll('?dl=0', '?dl=1');
    }
    return null;
  }

  static String? _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return segments.last;
  }

  static Future<String?> uploadResumeBytes({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required CloudSource source,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) return null;

    final storagePath = '$userId/resume.$ext';
    await Supabase.instance.client.storage
        .from('resumes')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = Supabase.instance.client.storage
        .from('resumes')
        .getPublicUrl(storagePath);

    await SupabaseService.updateProfile(userId, {
      'resume_url': url,
      'resume_cloud_source': source.name,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return url;
  }

  static String labelFor(CloudSource source) => switch (source) {
    CloudSource.googleDrive => 'Google Drive',
    CloudSource.dropbox => 'Dropbox',
    CloudSource.iCloud => 'iCloud',
    CloudSource.device => 'Device',
  };
}
