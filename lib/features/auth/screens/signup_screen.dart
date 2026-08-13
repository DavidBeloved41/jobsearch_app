import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router.dart';
import '../../../core/auth/email_verification_notifier.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

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
        // Create profile for the new user
        // Profile creation is critical and must not fail silently
        try {
          await SupabaseService.createProfile(
            response.user!.id,
            fullName: _fullNameController.text.trim(),
            accountType: _selectedAccountType,
          );
          debugPrint(
            'Signup: Profile created successfully for user ${response.user!.id}',
          );
        } catch (profileError) {
          debugPrint('Signup: Profile creation failed: $profileError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to create profile: ${profileError.toString()}. Please try again.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        if (!mounted) return;

        final session = Supabase.instance.client.auth.currentSession;
        // If a session exists immediately after signup we still prefer
        // to send the user to email verification flow for a clear UX.
        // Only route to dashboard after a deliberate authentication flow.
        if (session != null) {
          debugPrint(
            'Signup: session present after signUp; routing to email verification instead of dashboard',
          );
          ref
              .read(emailVerificationProvider.notifier)
              .setEmail(_emailController.text.trim());
          GoRouter.of(context).go(AppRoutes.emailVerification);
          return;
        }

        if (mounted) {
          ref
              .read(emailVerificationProvider.notifier)
              .setEmail(_emailController.text.trim());
          GoRouter.of(context).go(AppRoutes.emailVerification);
          return;
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start your job search journey today',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      label: const Text('Job seeker'),
                      selected: _selectedAccountType == 'job_seeker',
                      onSelected: (_) {
                        setState(() => _selectedAccountType = 'job_seeker');
                      },
                    ),
                    ChoiceChip(
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
                        setState(() => _obscurePassword = !_obscurePassword);
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
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create account'),
                ),
                const SizedBox(height: 24),
                if (_selectedAccountType == 'employer') ...[
                  const Text(
                    'Employers can sign up with this account type to post jobs and browse candidates.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                ],
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.textSecondary),
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
    );
  }
}
