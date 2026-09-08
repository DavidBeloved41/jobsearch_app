import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobsearch_app/app/router.dart';
import 'package:jobsearch_app/features/admin/widgets/admin_navigation_drawer.dart';

void main() {
  testWidgets('admin drawer exposes the registered destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          drawer: AdminNavigationDrawer(
            selectedRoute: AppRoutes.adminDashboard,
          ),
          body: SizedBox.shrink(),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Admin workspace'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  test('admin navigation uses the existing protected route definitions', () {
    expect(AppRoutes.adminDashboard, '/admin/dashboard');
    expect(AppRoutes.adminJobs, '/admin/jobs');
    expect(AppRoutes.adminUsers, '/admin/users');
    expect(AppRoutes.adminApplications, '/admin/applications');
  });
}
