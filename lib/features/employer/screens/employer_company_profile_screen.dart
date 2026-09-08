import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

class EmployerCompanyProfileScreen extends StatefulWidget {
  const EmployerCompanyProfileScreen({super.key});

  @override
  State<EmployerCompanyProfileScreen> createState() =>
      _EmployerCompanyProfileScreenState();
}

class _EmployerCompanyProfileScreenState
    extends State<EmployerCompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _foundedYearController = TextEditingController();
  final _aboutController = TextEditingController();
  String _companySize = '';
  static const _companySizes = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '501-1000',
    '1001+',
  ];

  bool _loading = true;
  bool _hasCompanyProfile = false;
  bool _saving = false;
  String? _logoUrl;
  Uint8List? _logoPreviewBytes;
  String? _logoFileName;

  @override
  void initState() {
    super.initState();
    _loadCompanyProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _foundedYearController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    try {
      final profile = await SupabaseService.getProfile(user.id);
      final role = SupabaseService.normalizeAccountType(
        profile?['account_type'],
      );
      if (role != 'employer') {
        if (!mounted) return;
        context.go(await SupabaseService.getRoleRoute(user.id));
        return;
      }

      debugPrint('[EMPLOYER PROFILE] Loading for userId: ${user.id}');

      // Load employer profile - NULL is a valid first-time state
      final company = await SupabaseService.getEmployerProfile(user.id);
      debugPrint(
        '[EMPLOYER PROFILE] Query result: ${company != null ? 'Found existing profile' : 'No profile exists (first-time)'}',
      );

      if (!mounted) return;
      setState(() {
        _nameController.text = company?['company_name'] as String? ?? '';
        _emailController.text =
            company?['company_email'] as String? ?? user.email ?? '';
        _phoneController.text = company?['company_phone'] as String? ?? '';
        _locationController.text = company?['location'] as String? ?? '';
        _industryController.text = company?['industry'] as String? ?? '';
        _websiteController.text = company?['website'] as String? ?? '';
        _foundedYearController.text =
            company?['founded_year']?.toString() ?? '';
        _companySize = company?['company_size'] as String? ?? '';
        _aboutController.text = company?['description'] as String? ?? '';
        _logoUrl = company?['logo_url'] as String?;
        _hasCompanyProfile = company != null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[EMPLOYER PROFILE ERROR] Actual error occurred: $e');
      if (mounted) {
        setState(() => _loading = false);
        // Only show error for actual exceptions, not for missing profile
        _showError(
          'Error loading profile. Please check your connection and try again.',
        );
      }
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() {
      _logoPreviewBytes = file.bytes;
      _logoFileName = file.name;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Your session has expired. Please sign in again.');
      return;
    }

    setState(() => _saving = true);
    try {
      var logoUrl = _logoUrl;
      if (_logoPreviewBytes != null && _logoFileName != null) {
        logoUrl = await SupabaseService.uploadCompanyLogo(
          posterId: user.id,
          bytes: _logoPreviewBytes!,
          fileName: _logoFileName!,
        );
        if (logoUrl == null) {
          throw StateError('Company logo upload failed.');
        }
      }

      final companyData = {
        'company_email': _emailController.text.trim(),
        'company_name': _nameController.text.trim(),
        'company_phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'industry': _industryController.text.trim(),
        'company_size': _companySize,
        'website': _websiteController.text.trim(),
        'founded_year': int.tryParse(_foundedYearController.text.trim()),
        'description': _aboutController.text.trim(),
        'logo_url': logoUrl,
      };
      if (_hasCompanyProfile) {
        await SupabaseService.updateEmployerProfile(user.id, companyData);
      } else {
        await SupabaseService.createEmployerProfile(user.id, companyData);
      }

      if (!mounted) return;
      setState(() {
        _logoUrl = logoUrl;
        _logoPreviewBytes = null;
        _logoFileName = null;
        _hasCompanyProfile = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company profile saved successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on PostgrestException catch (error) {
      debugPrint('Employer profile save error: $error');
      debugPrint('Code: ${error.code}');
      debugPrint('Details: ${error.details}');
      debugPrint('Hint: ${error.hint}');
      if (mounted) {
        setState(() => _saving = false);
        _showError(
          'Company profile save failed (${error.code}): ${error.message}',
        );
      }
    } catch (error) {
      debugPrint('Employer profile save error: $error');
      if (mounted) {
        setState(() => _saving = false);
        _showError('Company profile save failed: $error');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  int get _completedFields {
    return [
      _nameController.text,
      _emailController.text,
      _phoneController.text,
      _locationController.text,
      _industryController.text,
      _companySize,
      _websiteController.text,
      _foundedYearController.text,
      _aboutController.text,
      _logoPreviewBytes != null ? 'logo' : (_logoUrl ?? ''),
    ].where((value) => value.trim().isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Company Profile'),
        actions: [
          IconButton(
            tooltip: 'Save changes',
            onPressed: _loading || _saving ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogoCard(context),
                    const SizedBox(height: 16),
                    _buildCompletenessCard(context),
                    const SizedBox(height: 24),
                    _sectionTitle(context, 'Company Information'),
                    _field(
                      controller: _nameController,
                      label: 'Company name',
                      icon: Icons.business_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter the company name'
                          : null,
                    ),
                    _field(
                      controller: _emailController,
                      label: 'Company email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Enter a valid company email';
                        }
                        return null;
                      },
                    ),
                    _field(
                      controller: _phoneController,
                      label: 'Company phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    _field(
                      controller: _locationController,
                      label: 'Company location',
                      icon: Icons.location_on_outlined,
                    ),
                    _field(
                      controller: _industryController,
                      label: 'Industry',
                      icon: Icons.category_outlined,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _companySizes.contains(_companySize)
                          ? _companySize
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Company size',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      items: _companySizes
                          .map(
                            (size) => DropdownMenuItem(
                              value: size,
                              child: Text(size),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _companySize = value ?? '';
                      }),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _websiteController,
                      label: 'Company website',
                      icon: Icons.language_outlined,
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        final website = value?.trim() ?? '';
                        if (website.isNotEmpty &&
                            !RegExp(r'^https?://').hasMatch(website)) {
                          return 'Use a URL starting with http:// or https://';
                        }
                        return null;
                      },
                    ),
                    _field(
                      controller: _foundedYearController,
                      label: 'Founded year',
                      icon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final year = value?.trim() ?? '';
                        if (year.isEmpty) return null;
                        final parsed = int.tryParse(year);
                        final currentYear = DateTime.now().year;
                        if (parsed == null ||
                            parsed < 1800 ||
                            parsed > currentYear) {
                          return 'Enter a valid founded year';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'About the Company'),
                    TextFormField(
                      controller: _aboutController,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe your company, mission, culture, and what makes it a great place to work.',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 90),
                          child: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(context, 'Profile Preview'),
                    _buildPreviewCard(context),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLogoCard(BuildContext context) {
    final image = _logoPreviewBytes != null
        ? Image.memory(_logoPreviewBytes!, fit: BoxFit.cover)
        : _logoUrl != null && _logoUrl!.isNotEmpty
        ? Image.network(_logoUrl!, fit: BoxFit.cover)
        : const Icon(
            Icons.business_outlined,
            size: 42,
            color: AppColors.primary,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 76, height: 76, child: image),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company logo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use a clear logo for your employer profile.',
                    style: TextStyle(color: AppColors.textSec(context)),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_outlined),
                    label: Text(
                      _logoUrl == null ? 'Upload logo' : 'Change logo',
                    ),
                  ),
                  if (_logoUrl != null || _logoPreviewBytes != null)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _logoUrl = null;
                        _logoPreviewBytes = null;
                        _logoFileName = null;
                      }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove logo'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletenessCard(BuildContext context) {
    const totalFields = 10;
    final percentage = ((_completedFields / totalFields) * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Company profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _completedFields / totalFields),
            const SizedBox(height: 8),
            Text(
              percentage == 100
                  ? 'Your company profile is complete.'
                  : 'Complete the available company fields to help job seekers learn about your organization.',
              style: TextStyle(fontSize: 12, color: AppColors.textSec(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nameController.text.trim().isEmpty
                  ? 'Your company'
                  : _nameController.text.trim(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _locationController.text.trim().isEmpty
                  ? 'Add a company location'
                  : _locationController.text.trim(),
              style: TextStyle(color: AppColors.textSec(context)),
            ),
            const SizedBox(height: 16),
            Text(
              'About the company',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _aboutController.text.trim().isEmpty
                  ? 'Add a description of your organization.'
                  : _aboutController.text.trim(),
              style: TextStyle(color: AppColors.textSec(context), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.text(context),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
