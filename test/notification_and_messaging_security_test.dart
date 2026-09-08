import 'package:flutter_test/flutter_test.dart';
import 'package:jobsearch_app/core/supabase/supabase_service.dart';
import 'package:jobsearch_app/features/messages/widgets/unread_message_icon.dart';
import 'package:jobsearch_app/core/utils/external_url_policy.dart';

void main() {
  test('unread count is limited to unread inbound messages for the user', () {
    final count = SupabaseService.countUnreadMessages([
      {'sender_id': 'other', 'receiver_id': 'me', 'is_read': false},
      {'sender_id': 'other', 'receiver_id': 'me', 'is_read': true},
      {'sender_id': 'me', 'receiver_id': 'other', 'is_read': false},
      {
        'sender_id': 'third-party',
        'receiver_id': 'someone-else',
        'is_read': false,
      },
    ], 'me');

    expect(count, 1);
  });

  test('role normalization does not elevate arbitrary client values', () {
    expect(SupabaseService.normalizeAccountType('admin'), 'admin');
    expect(SupabaseService.normalizeAccountType('administrator'), 'admin');
    expect(SupabaseService.normalizeAccountType('super_admin'), 'unknown');
    expect(SupabaseService.normalizeAccountType(''), 'unknown');
  });

  test('protected application access requires confirmed email state', () {
    expect(SupabaseService.isEmailConfirmedAt(null), isFalse);
    expect(SupabaseService.isEmailConfirmedAt(''), isFalse);
    expect(SupabaseService.isEmailConfirmedAt('2026-09-06T00:00:00Z'), isTrue);
  });

  test('message send supports both employer and job seeker directions', () {
    expect(
      SupabaseService.canMessageBetweenRoles('employer', 'job_seeker'),
      isTrue,
    );
    expect(
      SupabaseService.canMessageBetweenRoles('job_seeker', 'employer'),
      isTrue,
    );
    expect(
      SupabaseService.canMessageBetweenRoles('admin', 'employer'),
      isFalse,
    );
  });

  test(
    'application status validation accepts workflow values and rejects arbitrary input',
    () {
      expect(SupabaseService.isValidApplicationStatus('interviewing'), isTrue);
      expect(SupabaseService.isValidApplicationStatus('offered'), isTrue);
      expect(SupabaseService.isValidApplicationStatus('reviewing'), isTrue);
      expect(SupabaseService.isValidApplicationStatus('DROP TABLE'), isFalse);
    },
  );

  test('application workflow accepts the required progression values', () {
    for (final status in [
      'applied',
      'reviewing',
      'interviewing',
      'offered',
      'rejected',
      'declined',
    ]) {
      expect(
        SupabaseService.isValidApplicationStatus(status),
        isTrue,
        reason: 'Expected $status to be a valid server status',
      );
    }
  });

  test('message authorization rejects impersonation and unrelated roles', () {
    expect(
      SupabaseService.canMessageBetweenRoles('employer', 'job_seeker'),
      isTrue,
    );
    expect(
      SupabaseService.canMessageBetweenRoles('job_seeker', 'employer'),
      isTrue,
    );
    expect(
      SupabaseService.canMessageBetweenRoles('admin', 'job_seeker'),
      isFalse,
    );
    expect(
      SupabaseService.canMessageBetweenRoles('employer', 'employer'),
      isFalse,
    );
  });

  test('legacy recruiter and candidate roles normalize to supported roles', () {
    expect(SupabaseService.normalizeAccountType('recruiter'), 'employer');
    expect(SupabaseService.normalizeAccountType('candidate'), 'job_seeker');
    expect(
      SupabaseService.canMessageBetweenRoles('recruiter', 'candidate'),
      isTrue,
    );
    expect(
      SupabaseService.canMessageBetweenRoles('candidate', 'recruiter'),
      isTrue,
    );
  });

  test('unread badge is hidden at zero and capped for large counts', () {
    expect(unreadMessageBadgeLabel(0), isEmpty);
    expect(unreadMessageBadgeLabel(2), '2');
    expect(unreadMessageBadgeLabel(100), '99+');
  });

  test('message delivery status is derived only from database timestamps', () {
    expect(SupabaseService.messageDeliveryStatus({'id': '1'}), 'Sent');
    expect(
      SupabaseService.messageDeliveryStatus({
        'id': '1',
        'delivered_at': '2026-09-07T10:00:00Z',
      }),
      'Delivered',
    );
    expect(
      SupabaseService.messageDeliveryStatus({
        'id': '1',
        'delivered_at': '2026-09-07T10:00:00Z',
        'seen_at': '2026-09-07T10:01:00Z',
      }),
      'Read',
    );
  });

  test(
    'resume URL policy rejects arbitrary external hosts and non-HTTPS URLs',
    () {
      expect(
        ExternalUrlPolicy.isAllowedResumeUrl(
          'https://drive.google.com/file/d/abc',
        ),
        isTrue,
      );
      expect(
        ExternalUrlPolicy.isAllowedResumeUrl('https://example.com/resume.pdf'),
        isFalse,
      );
      expect(
        ExternalUrlPolicy.isAllowedResumeUrl('javascript:alert(1)'),
        isFalse,
      );
    },
  );
}
