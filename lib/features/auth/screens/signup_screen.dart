import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/auth/email_verification_notifier.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_brand_header.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final String initialAccountType;

  const SignupScreen({super.key, this.initialAccountType = 'job_seeker'});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedAccountType = 'job_seeker';

  @override
  void initState() {
    super.initState();
    _selectedAccountType = widget.initialAccountType;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    // Extra defensive check: ensure form is valid before proceeding
    if (!_formKey.currentState!.validate()) {
      debugPrint('Signup: form invalid, aborting');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _fullNameController.text.trim(),
          'account_type': _selectedAccountType,
        },
      );

      if (response.user != null) {
        final user = response.user!;
        final currentSession = Supabase.instance.client.auth.currentSession;

        // Do not create a profile from a temporary signup session. A user must
        // complete email verification before they are considered authenticated.
        if (currentSession != null &&
            SupabaseService.canAccessAuthenticatedApp(
              session: currentSession,
              user: user,
            )) {
          debugPrint(
            'Signup: verified session present; profile creation deferred until after login',
          );
        } else if (currentSession != null) {
          debugPrint(
            'Signup: unverified temporary session detected; signing out before verification',
          );
          await Supabase.instance.client.auth.signOut();
        } else {
          debugPrint(
            'Signup: no session returned; deferring profile creation until verified login',
          );
        }

        if (!mounted) return;

        ref
            .read(emailVerificationProvider.notifier)
            .setEmail(_emailController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification code sent. Enter it in the SmartJob app to activate your account.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        GoRouter.of(context).go(AppRoutes.emailVerification);
        return;
      }
    } on AuthException catch (error) {
      debugPrint('Signup authentication failed: ${error.code}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlySignupError(error)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlySignupError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already') || message.contains('registered')) {
      return 'An account with this email already exists.';
    }
    if (message.contains('password') || message.contains('weak')) {
      return 'Password does not meet the minimum requirements.';
    }
    if (message.contains('email') && message.contains('invalid')) {
      return 'Please enter a valid email address.';
    }
    return "We couldn't create your account. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthBrandHeader(
                      title: 'Create your account',
                      subtitle:
                          'Join SmartJob and take the next step in your career.',
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Choose your account type',
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          avatar: const Icon(
                            Icons.person_search_outlined,
                            size: 18,
                          ),
                          label: const Text('Job seeker'),
                          selected: _selectedAccountType == 'job_seeker',
                          onSelected: (_) {
                            setState(() => _selectedAccountType = 'job_seeker');
                          },
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.business_outlined, size: 18),
                          label: const Text('Employer'),
                          selected: _selectedAccountType == 'employer',
                          onSelected: (_) {
                            setState(() => _selectedAccountType = 'employer');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Full name field
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Create a password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm password field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        hintText: 'Confirm your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Sign up button
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              // Provide immediate feedback if form is invalid
                              if (!_formKey.currentState!.validate()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please complete the form'),
                                  ),
                                );
                                return;
                              }
                              _signup();
                            },
                      child: _isLoading
                          ? CircularProgressIndicator(
                              color: colorScheme.onPrimary,
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 24),
                    if (_selectedAccountType == 'employer') ...[
                      Text(
                        'Employers can sign up with this account type to post jobs and browse candidates.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
