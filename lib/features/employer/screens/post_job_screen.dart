import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

class PostJobScreen extends StatefulWidget {
  final Map<String, dynamic>? job;

  const PostJobScreen({super.key, this.job});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();

  Uint8List? _logoBytes;
  String? _existingLogoUrl;

  String _employmentType = 'full-time';
  String _workModel = 'all';
  bool _isSubmitting = false;
  bool _isInitializing = true;
  String? _initializationError;

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _initializationError = 'You must be logged in to post a job.';
      });
      return;
    }

    final j = widget.job;
    if (j != null) {
      if (j['title'] is String) _titleController.text = j['title'];
      if (j['company_name'] is String) {
        _companyController.text = j['company_name'];
      }
      if (j['location'] is String) _locationController.text = j['location'];
      if (j['description'] is String) {
        _descriptionController.text = j['description'];
      }
      if (j['employment_type'] is String) {
        _employmentType = j['employment_type'];
      }
      if (j['work_model'] is String) _workModel = j['work_model'];
      if (j['salary_min'] != null) {
        _salaryMinController.text = j['salary_min'].toString();
      }
      if (j['salary_max'] != null) {
        _salaryMaxController.text = j['salary_max'].toString();
      }
    }

    if (mounted) {
      setState(() => _isInitializing = false);
    }

    // Profile data is optional and must never gate the form.
    try {
      final employerProfile = await SupabaseService.getEmployerProfile(userId);
      if (!mounted || widget.job != null || employerProfile == null) return;
      final companyName = employerProfile['company_name'];
      if (companyName is String && _companyController.text.isEmpty) {
        setState(() => _companyController.text = companyName);
      }
    } on PostgrestException catch (error) {
      debugPrint('[POST JOB] Optional profile load failed');
      debugPrint('message: ${error.message}');
      debugPrint('code: ${error.code}');
      debugPrint('details: ${error.details}');
      debugPrint('hint: ${error.hint}');
    } catch (error) {
      debugPrint('[POST JOB] Optional profile load failed: $error');
    }
  }

  Future<void> _pickLogo() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      if (file.bytes == null) return;
      setState(() {
        _logoBytes = file.bytes;
        _existingLogoUrl = null;
      });
    } catch (e) {
      debugPrint('Logo pick failed: $e');
    }
  }

  Future<void> _submit() async {
    if (_isInitializing || _initializationError != null) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post a job')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final salaryMin = _salaryMinController.text.trim().isEmpty
          ? null
          : int.tryParse(_salaryMinController.text.trim());
      final salaryMax = _salaryMaxController.text.trim().isEmpty
          ? null
          : int.tryParse(_salaryMaxController.text.trim());

      if (salaryMin != null && salaryMax != null && salaryMin > salaryMax) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Minimum salary cannot exceed maximum salary'),
            ),
          );
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      final Map<String, dynamic> job = {
        'title': _titleController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'employment_type': _employmentType,
        'work_model': _workModel,
        if (salaryMin != null) 'salary_min': salaryMin,
        if (salaryMax != null) 'salary_max': salaryMax,
      };

      final editingExisting = widget.job != null && widget.job!['id'] != null;

      if (editingExisting) {
        final jobId = widget.job!['id'];
        if (jobId is! String) {
          throw StateError('Invalid job ID');
        }

        final payload = Map<String, dynamic>.from(job)
          ..removeWhere(
            (k, v) => k == 'id' || k == 'created_at' || k == 'updated_at',
          );

        await SupabaseService.updateJob(jobId, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop({'updated': true});
      } else {
        final created = await SupabaseService.createJob(userId, job);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job posted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(created);
      }
    } on PostgrestException catch (error) {
      debugPrint('[POST JOB] Save - PostgREST error');
      debugPrint('message: ${error.message}');
      debugPrint('code: ${error.code}');
      debugPrint('details: ${error.details}');
      debugPrint('hint: ${error.hint}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'message: ${error.message}\n'
            'code: ${error.code}\n'
            'details: ${error.details}\n'
            'hint: ${error.hint}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      debugPrint('[POST JOB] Save - error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      backgroundColor: AppColors.bg(context),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing job posting...'),
          ],
        ),
      );
    }

    if (_initializationError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Unable to load the job posting form.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SelectableText(
                _initializationError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () {
                      setState(() {
                        _isInitializing = true;
                        _initializationError = null;
                      });
                      _initialize();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Job title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'Company name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _employmentType,
              items: const [
                DropdownMenuItem(value: 'full-time', child: Text('Full-time')),
                DropdownMenuItem(value: 'part-time', child: Text('Part-time')),
                DropdownMenuItem(value: 'contract', child: Text('Contract')),
              ],
              onChanged: (v) =>
                  setState(() => _employmentType = v ?? 'full-time'),
              decoration: const InputDecoration(labelText: 'Employment type'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _workModel,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Any')),
                DropdownMenuItem(value: 'remote', child: Text('Remote')),
                DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                DropdownMenuItem(value: 'on-site', child: Text('On-site')),
              ],
              onChanged: (v) => setState(() => _workModel = v ?? 'all'),
              decoration: const InputDecoration(labelText: 'Work model'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _salaryMinController,
                    decoration: const InputDecoration(
                      labelText: 'Salary min (GHS)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _salaryMaxController,
                    decoration: const InputDecoration(
                      labelText: 'Salary max (GHS)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 6,
              maxLines: 12,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 30) {
                  return 'Description must be at least 30 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_logoBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _logoBytes!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_existingLogoUrl != null &&
                    _existingLogoUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _existingLogoUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, st) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.bord(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                if (_logoBytes != null ||
                    (_existingLogoUrl?.isNotEmpty ?? false))
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Logo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_isSubmitting ||
                        _isInitializing ||
                        _initializationError != null)
                    ? null
                    : _submit,
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Publishing...'),
                        ],
                      )
                    : const Text('Post Job'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
