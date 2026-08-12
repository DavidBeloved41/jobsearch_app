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
  String? _logoFileName;
  String? _existingLogoUrl;

  String _employmentType = 'full-time';
  String _workModel = 'all';
  bool _isSubmitting = false;

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
    final j = widget.job;
    if (j != null) {
      _titleController.text = j['title'] as String? ?? '';
      _companyController.text = j['company_name'] as String? ?? '';
      _locationController.text = j['location'] as String? ?? '';
      _descriptionController.text = j['description'] as String? ?? '';
      _employmentType = j['employment_type'] as String? ?? _employmentType;
      _workModel = j['work_model'] as String? ?? _workModel;
      _salaryMinController.text = (j['salary_min']?.toString() ?? '');
      _salaryMaxController.text = (j['salary_max']?.toString() ?? '');
      _existingLogoUrl =
          j['company_logo_url'] as String? ??
          (j['companies'] as Map<String, dynamic>?)?['logo_url'] as String?;
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
        _logoFileName = file.name;
        _existingLogoUrl = null;
      });
    } catch (e) {
      debugPrint('Logo pick failed: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to post a job')));
      return;
    }

    setState(() => _isSubmitting = true);

    final job = {
      'title': _titleController.text.trim(),
      'company_name': _companyController.text.trim(),
      'location': _locationController.text.trim(),
      'description': _descriptionController.text.trim(),
      'employment_type': _employmentType,
      'work_model': _workModel,
      if (_salaryMinController.text.trim().isNotEmpty)
        'salary_min': int.tryParse(_salaryMinController.text.trim()),
      if (_salaryMaxController.text.trim().isNotEmpty)
        'salary_max': int.tryParse(_salaryMaxController.text.trim()),
      'is_active': true,
    };

    try {
      // Upload logo if one was picked
      if (_logoBytes != null && _logoFileName != null) {
        final uploadedUrl = await SupabaseService.uploadCompanyLogo(
          posterId: userId,
          bytes: _logoBytes!,
          fileName: _logoFileName!,
        );
        if (uploadedUrl != null) job['company_logo_url'] = uploadedUrl;
      } else if (_existingLogoUrl != null) {
        job['company_logo_url'] = _existingLogoUrl;
      }

      if (widget.job != null && widget.job!['id'] != null) {
        // Edit existing job
        final jobId = widget.job!['id'] as String;
        final payload = Map<String, dynamic>.from(job)
          ..removeWhere(
            (k, v) => k == 'id' || k == 'created_at' || k == 'poster_id',
          );
        await SupabaseService.updateJob(jobId, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job updated successfully')),
          );
          Navigator.of(context).pop({'updated': true});
        }
      } else {
        final created = await SupabaseService.createJob(userId, job);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job posted successfully')),
          );
          Navigator.of(context).pop(created);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save job: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      backgroundColor: AppColors.bg(context),
      body: Padding(
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
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
                  DropdownMenuItem(
                    value: 'full-time',
                    child: Text('Full-time'),
                  ),
                  DropdownMenuItem(
                    value: 'part-time',
                    child: Text('Part-time'),
                  ),
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
                        labelText: 'Salary min',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMaxController,
                      decoration: const InputDecoration(
                        labelText: 'Salary max',
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
                    Image.memory(
                      _logoBytes!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  else if (_existingLogoUrl != null)
                    Image.network(
                      _existingLogoUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _pickLogo,
                    child: const Text('Choose logo'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post job'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
