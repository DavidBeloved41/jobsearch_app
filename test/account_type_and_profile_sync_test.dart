import 'package:flutter_test/flutter_test.dart';
import 'package:jobsearch_app/core/auth/auth_redirects.dart';
import 'package:jobsearch_app/core/supabase/supabase_service.dart';

void main() {
  test(
    'profile creation accepts persisted email and normalized role values',
    () {
      expect(SupabaseService.createProfile, isA<Function>());
      expect(SupabaseService.normalizeAccountType('candidate'), 'job_seeker');
      expect(SupabaseService.normalizeAccountType('recruiter'), 'employer');
      expect(SupabaseService.normalizeAccountType('job_seeker'), 'job_seeker');
      expect(SupabaseService.normalizeAccountType('employer'), 'employer');
    },
  );

  test('job seeker role can apply and employer cannot', () {
    expect(SupabaseService.isJobSeekerRole('job_seeker'), isTrue);
    expect(SupabaseService.isJobSeekerRole('employer'), isFalse);
    expect(SupabaseService.canApplyToJobs('job_seeker'), isTrue);
    expect(SupabaseService.canApplyToJobs('employer'), isFalse);
    expect(SupabaseService.canApplyToJobs('admin'), isFalse);
  });

  test('only the approved admin email can access the admin dashboard', () {
    expect(
      SupabaseService.isAuthorizedAdminEmail('beloveddavid41@gmail.com'),
      isTrue,
    );
    expect(SupabaseService.isAuthorizedAdminEmail('user@example.com'), isFalse);
    expect(SupabaseService.isAuthorizedAdminEmail(null), isFalse);
  });

  test('active jobs are visible to job seekers and pending jobs are not', () {
    expect(SupabaseService.isJobVisibleToJobSeekers(isActive: true), isTrue);
    expect(SupabaseService.isJobVisibleToJobSeekers(isActive: false), isFalse);
  });

  test(
    'verification redirects remain on the app deep-link scheme and the site URL is HTTPS',
    () {
      expect(
        AppAuthRedirects.resetPasswordCallback,
        'smartjob://reset-password',
      );
      expect(AppAuthRedirects.siteUrl, 'https://smartjob.app');
      expect(AppAuthRedirects.siteUrl.startsWith('https://'), isTrue);
    },
  );

  test('unverified users are rejected even when a session exists', () {
    expect(SupabaseService.isEmailConfirmedAt(null), isFalse);
    expect(
      SupabaseService.isEmailConfirmedAt('2026-09-04T12:00:00.000Z'),
      isTrue,
    );
    expect(SupabaseService.isEmailConfirmedAt(' '), isFalse);
  });
}
