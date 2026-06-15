import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _yearsOfExperienceController = TextEditingController();
  bool _isLoading = false;
  bool _isFetching = true;
  bool _isOpenToWork = true;
  String? _profilePhotoUrl;
  bool _isUploadingPhoto = false;
  String _preferredWorkModel = 'all';
  String _preferredEmploymentType = 'all';
  final _desiredMinSalaryController = TextEditingController();
  final _desiredMaxSalaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _jobTitleController.dispose();
    _yearsOfExperienceController.dispose();
    _desiredMinSalaryController.dispose();
    _desiredMaxSalaryController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user ID available for loading profile');
        return;
      }
      final profile = await SupabaseService.getProfile(userId);
      if (profile != null) {
        _fullNameController.text = profile['full_name'] ?? '';
        _phoneController.text = profile['phone_number'] ?? '';
        _locationController.text = profile['location'] ?? '';
        _bioController.text = profile['bio'] ?? '';
        _jobTitleController.text = profile['job_title'] ?? '';
        _yearsOfExperienceController.text =
            profile['years_of_experience']?.toString() ?? '';
        setState(() {
          _isOpenToWork = profile['is_open_to_work'] ?? true;
          _profilePhotoUrl = profile['profile_photo_url'];
          _preferredWorkModel =
              profile['preferred_work_model'] as String? ?? 'all';
          _preferredEmploymentType =
              profile['preferred_employment_type'] as String? ?? 'all';
          _desiredMinSalaryController.text =
              profile['desired_min_salary']?.toString() ?? '';
          _desiredMaxSalaryController.text =
              profile['desired_max_salary']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();

      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text(
              'Select photo',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    'Gallery',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    'Camera',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final userId = Supabase.instance.client.auth.currentUser!.id;
      final bytes = await image.readAsBytes();
      final fileName = '$userId/avatar.jpg';

      debugPrint('Uploading photo to avatars bucket');
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      debugPrint('Photo uploaded successfully to: $fileName');

      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
      debugPrint('Public URL: $url');

      await SupabaseService.updateProfile(userId, {
        'profile_photo_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _profilePhotoUrl = url;
        _isUploadingPhoto = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        final raw = e.toString();
        final lower = raw.toLowerCase();
        final isRls =
            lower.contains('row-level security') ||
            lower.contains('unauthorized') ||
            lower.contains('403');
        final details = raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRls
                  ? 'Photo upload blocked by storage RLS (403). Check Supabase bucket `avatars` policies (and file path prefix like `<auth.uid()>/...`).'
                  : 'Failed to upload photo: $details',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to save your profile'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      await SupabaseService.updateProfile(userId, {
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'years_of_experience': int.tryParse(
          _yearsOfExperienceController.text.trim(),
        ),
        'is_open_to_work': _isOpenToWork,
        'preferred_work_model': _preferredWorkModel,
        'preferred_employment_type': _preferredEmploymentType,
        'desired_min_salary':
            int.tryParse(_desiredMinSalaryController.text.trim()),
        'desired_max_salary':
            int.tryParse(_desiredMaxSalaryController.text.trim()),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          'Edit Profile',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: _isFetching
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: GestureDetector(
                        onTap: _pickAndUploadPhoto,
                        child: Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                                image: _profilePhotoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_profilePhotoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _profilePhotoUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                            ),
                            if (_isUploadingPhoto)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? colorScheme.surface
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Open to work toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surface
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? colorScheme.outline.withValues(alpha: 0.3)
                              : colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Open to work',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Let recruiters know you\'re available',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOpenToWork,
                            onChanged: (value) =>
                                setState(() => _isOpenToWork = value),
                            activeThumbColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Personal Information
                    const _SectionLabel(label: 'Personal Information'),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _fullNameController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(
                          Icons.person_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _locationController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'e.g. Accra, Ghana',
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Professional Information
                    const _SectionLabel(label: 'Professional Information'),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _jobTitleController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Job title',
                        hintText: 'e.g. Flutter Developer',
                        prefixIcon: Icon(
                          Icons.work_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _yearsOfExperienceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Years of experience',
                        hintText: 'e.g. 3',
                        prefixIcon: Icon(
                          Icons.timeline_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell recruiters about yourself...',
                        prefixIcon: Icon(
                          Icons.notes_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const _SectionLabel(label: 'Job Preferences'),
                    const SizedBox(height: 12),
                    Text(
                      'Preferred work model',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final option in ['all', 'remote', 'hybrid', 'on-site'])
                          ChoiceChip(
                            label: Text(option == 'all' ? 'Any' : option),
                            selected: _preferredWorkModel == option,
                            onSelected: (_) =>
                                setState(() => _preferredWorkModel = option),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Preferred employment type',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final option in ['all', 'full-time', 'contract'])
                          ChoiceChip(
                            label: Text(option == 'all' ? 'Any' : option),
                            selected: _preferredEmploymentType == option,
                            onSelected: (_) =>
                                setState(() => _preferredEmploymentType = option),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _desiredMinSalaryController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min salary',
                              prefixText: '\$ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _desiredMaxSalaryController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max salary',
                              prefixText: '\$ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Used to improve your For You match scores',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save changes'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface.withValues(alpha: 0.55),
        letterSpacing: 0.5,
      ),
    );
  }
}
