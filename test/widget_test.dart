import 'package:flutter_test/flutter_test.dart';
import 'package:jobsearch_app/core/supabase/supabase_service.dart';
import 'package:jobsearch_app/core/services/ai_service.dart';
import 'package:jobsearch_app/core/services/match_score_service.dart';

void main() {
  group('SupabaseService auth and salary guard logic', () {
    test('normalizes account types consistently', () {
      expect(SupabaseService.normalizeAccountType('job_seeker'), 'job_seeker');
      expect(SupabaseService.normalizeAccountType('Job Seeker'), 'job_seeker');
      expect(SupabaseService.normalizeAccountType('Employer'), 'employer');
      expect(SupabaseService.normalizeAccountType('admin'), 'admin');
      expect(SupabaseService.normalizeAccountType('unknown'), 'unknown');
    });

    test('treats confirmed emails as active and unconfirmed as blocked', () {
      expect(
        SupabaseService.isEmailConfirmedAt('2026-09-02T00:00:00Z'),
        isTrue,
      );
      expect(SupabaseService.isEmailConfirmedAt(null), isFalse);
      expect(SupabaseService.isEmailConfirmedAt(''), isFalse);
    });

    test(
      'formats Ghana Cedi salaries without inconsistent currency output',
      () {
        expect(
          SupabaseService.formatSalaryDisplay(
            min: 3000,
            max: 5000,
            currency: 'GHS',
          ),
          'GH₵3,000 - GH₵5,000',
        );

        expect(
          SupabaseService.formatSalaryDisplay(
            min: 3000,
            max: 3000,
            currency: 'GHS',
          ),
          'GH₵3,000',
        );
        expect(
          SupabaseService.formatSalaryDisplay(min: 3000, currency: 'GHS'),
          'GH₵3,000',
        );
        expect(
          SupabaseService.formatSalaryDisplay(
            min: 3000,
            max: 5000,
            currency: 'USD',
          ),
          'GH₵3,000 - GH₵5,000',
        );
      },
    );

    test(
      'match score uses job requirements and changes with candidate evidence',
      () {
        final job = {
          'title': 'Flutter Developer',
          'description': 'Build mobile applications.',
          'required_skills': ['Flutter', 'Dart', 'Firebase'],
        };
        final strong = MatchScoreService.calculateDetailed(
          job: job,
          userSkillNames: ['Flutter', 'Dart'],
          resumeText: 'Flutter Dart Firebase developer',
        );
        final weak = MatchScoreService.calculateDetailed(
          job: job,
          userSkillNames: ['Accounting'],
          resumeText: 'Accounting and auditing experience',
        );

        expect(
          strong.matchedSkills,
          containsAll(['Flutter', 'Dart', 'Firebase']),
        );
        expect(strong.missingSkills, isEmpty);
        expect(
          weak.missingSkills,
          containsAll(['Flutter', 'Dart', 'Firebase']),
        );
        expect(strong.totalScore, greaterThan(weak.totalScore));
      },
    );

    test('AI match response validation rejects invalid scores', () {
      expect(AiService.parseJobMatchResponse({'match_score': 101}), isNull);

      final result = AiService.parseJobMatchResponse({
        'match_score': 82.7,
        'matching_skills': ['Flutter'],
        'missing_skills': ['Docker'],
        'recommendations': ['Learn Docker'],
      });
      expect(result?['match_score'], 83);
      expect(result?['matching_skills'], ['Flutter']);
      expect(result?['missing_skills'], ['Docker']);
    });
  });
}
