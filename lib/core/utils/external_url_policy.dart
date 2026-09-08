class ExternalUrlPolicy {
  static bool isAllowedResumeUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    return host == 'drive.google.com' ||
        host == 'www.dropbox.com' ||
        host == 'dl.dropboxusercontent.com' ||
        host.endsWith('.supabase.co');
  }

  static bool isAllowedResumeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && isAllowedResumeUri(uri);
  }
}
