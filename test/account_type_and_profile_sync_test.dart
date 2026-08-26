import 'package:flutter_test/flutter_test.dart';
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
}
