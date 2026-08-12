import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

bool _isPasswordRecoveryLink(Uri uri) {
  return uri.path == AppRoutes.resetPassword ||
      uri.host == 'reset-password' ||
      uri.queryParameters['type'] == 'recovery' ||
      uri.path.contains('/auth/v1/verify');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService init skipped: $e');
  }
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  authNotifier = AuthNotifier();
  var routerInitialLocation = AppRoutes.splash;
  final appLinks = AppLinks();
  try {
    final initialLink = await appLinks.getInitialLink();
    debugPrint('Initial deep link: $initialLink');
    if (initialLink != null) {
      debugPrint('Processing URL: $initialLink');
      if (_isPasswordRecoveryLink(initialLink)) {
        authNotifier.setPasswordRecoveryFromLink(initialLink);
        routerInitialLocation = AppRoutes.resetPassword;
      }
      await Supabase.instance.client.auth.getSessionFromUrl(initialLink);
      debugPrint('Session processed from URL');
    }
  } catch (e) {
    debugPrint('Error handling initial link: $e');
  }

  appRouter = createRouter(initialLocation: routerInitialLocation);

  appLinks.uriLinkStream.listen(
    (Uri? link) async {
      debugPrint('Deep link received: $link');
      if (link != null) {
        if (_isPasswordRecoveryLink(link)) {
          authNotifier.setPasswordRecoveryFromLink(link);
          appRouter.go(AppRoutes.resetPassword);
        }
        await Supabase.instance.client.auth.getSessionFromUrl(link);
      }
    },
    onError: (err) {
      debugPrint('Error handling link: $err');
    },
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'SmartJob',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
