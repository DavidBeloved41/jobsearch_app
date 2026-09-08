class AtsAnalysisResult {
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final int matchPercent;

  const AtsAnalysisResult({
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.matchPercent,
  });
}

class AtsKeywordService {
  static const _stopWords = {
    'the',
    'and',
    'for',
    'with',
    'you',
    'your',
    'our',
    'will',
    'this',
    'that',
    'from',
    'have',
    'has',
    'are',
    'was',
    'been',
    'being',
    'into',
    'about',
    'over',
    'such',
    'their',
    'they',
    'them',
    'able',
    'work',
    'team',
    'role',
    'job',
    'experience',
    'years',
    'required',
    'preferred',
  };

  static AtsAnalysisResult analyze({
    required Map<String, dynamic> job,
    required List<String> userSkillNames,
    String? resumeText,
  }) {
    final jobText = [
      job['title'] as String? ?? '',
      job['description'] as String? ?? '',
    ].join(' ').toLowerCase();

    final resumeLower = (resumeText ?? '').toLowerCase();
    final userText = [
      resumeLower,
      ...userSkillNames.map((s) => s.toLowerCase()),
    ].join(' ');

    final keywords = _extractKeywords(jobText);
    if (keywords.isEmpty) {
      return const AtsAnalysisResult(
        matchedKeywords: [],
        missingKeywords: [],
        matchPercent: 0,
      );
    }

    final matched = <String>[];
    final missing = <String>[];

    for (final keyword in keywords) {
      if (userText.contains(keyword)) {
        matched.add(keyword);
      } else {
        missing.add(keyword);
      }
    }

    final percent = ((matched.length / keywords.length) * 100).round().clamp(
      0,
      100,
    );

    return AtsAnalysisResult(
      matchedKeywords: matched,
      missingKeywords: missing.take(12).toList(),
      matchPercent: percent,
    );
  }

  static List<String> _extractKeywords(String text) {
    final words = text
        .replaceAll(RegExp(r'[^a-z0-9+#.\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();

    final freq = <String, int>{};
    for (final word in words) {
      freq[word] = (freq[word] ?? 0) + 1;
    }

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(20).map((e) => e.key).toList();
  }
}
