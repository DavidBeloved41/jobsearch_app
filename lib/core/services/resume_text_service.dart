import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import '../utils/external_url_policy.dart';

class ResumeTextService {
  static Future<String?> fromProfile(Map<String, dynamic>? profile) async {
    final url = profile?['resume_url'] as String?;
    if (url == null || url.trim().isEmpty) return null;
    try {
      final storagePath = _storagePathFromUrl(url);
      if (storagePath == null && !ExternalUrlPolicy.isAllowedResumeUrl(url)) {
        return null;
      }
      final downloadUrl = storagePath == null
          ? url
          : await Supabase.instance.client.storage
                .from('resumes')
                .createSignedUrl(storagePath, 300);
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        debugPrint(
          'ResumeTextService: resume download failed (${response.statusCode})',
        );
        return null;
      }
      final extension = _extensionFromUrl(url);
      return extract(response.bodyBytes, extension);
    } catch (error) {
      debugPrint('ResumeTextService: resume retrieval failed: $error');
      return null;
    }
  }

  static String? extract(Uint8List bytes, String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return _extractPdf(bytes);
      case 'docx':
        return _extractDocx(bytes);
      case 'doc':
        return null;
      default:
        return null;
    }
  }

  static String? _extractPdf(Uint8List bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final buffer = StringBuffer();
      for (var page = 0; page < document.pages.count; page++) {
        final text = PdfTextExtractor(
          document,
        ).extractText(startPageIndex: page, endPageIndex: page);
        if (text.trim().isNotEmpty) buffer.writeln(text);
      }
      document.dispose();
      return _clean(buffer.toString());
    } catch (error) {
      debugPrint('ResumeTextService: PDF extraction failed: $error');
      return null;
    }
  }

  static String? _extractDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.files.firstWhere(
        (file) => file.name == 'word/document.xml',
      );
      final xml = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final text = xml
          .findAllElements('w:t')
          .map((node) => node.innerText)
          .join(' ');
      return _clean(text);
    } catch (error) {
      debugPrint('ResumeTextService: DOCX extraction failed: $error');
      return null;
    }
  }

  static String _extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot + 1).split('?').first;
  }

  static String? _storagePathFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    const marker = '/storage/v1/object/';
    final markerIndex = uri.path.indexOf(marker);
    if (markerIndex == -1) return null;
    final remainder = uri.path.substring(markerIndex + marker.length);
    final segments = remainder.split('/');
    if (segments.length < 3 || segments[1] != 'resumes') return null;
    return segments.sublist(2).join('/');
  }

  static String? _clean(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}
