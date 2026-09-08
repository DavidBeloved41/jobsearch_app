import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/resume_templates.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/cloud_document_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  bool _hasResume = false;
  String? _resumeName;
  String? _uploadDate;
  bool _isUploading = false;
  bool _isGenerating = false;
  final _draftController = TextEditingController();
  bool _draftLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadExistingResume();
    _loadDraft();
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final draft = await OfflineCacheService.getResumeDraft();
    if (draft != null && draft.isNotEmpty) {
      _draftController.text = draft;
    }
    setState(() => _draftLoaded = true);
  }

  Future<void> _saveDraft() async {
    await OfflineCacheService.saveResumeDraft(_draftController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved locally'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _loadExistingResume() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user ID available for loading resume');
        return;
      }
      final profile = await SupabaseService.getProfile(userId);
      if (profile != null && profile['resume_url'] != null) {
        setState(() {
          _hasResume = true;
          _resumeName = 'My Resume';
          _uploadDate = 'Previously uploaded';
        });
      }
    } catch (e) {
      debugPrint('Error loading resume: $e');
    }
  }

  Future<void> _generateAiResume() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isGenerating = true);
    try {
      final profile = await SupabaseService.getProfile(userId);
      final skills = await SupabaseService.getUserSkillNames(userId);
      final draft = await AiService.generateResumeDraft(
        profile: profile,
        skills: skills,
        targetRole: profile?['job_title'] as String?,
      );
      if (draft != null && mounted) {
        _draftController.text = draft;
        await _saveDraft();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AiService.isConfigured
                  ? 'AI resume draft generated'
                  : 'AI service is unavailable. Please try again later.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _importFromCloud(CloudSource source) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isUploading = true);
    try {
      final picked = await CloudDocumentService.pickFromCloudPicker(source);
      if (picked == null) {
        setState(() => _isUploading = false);
        return;
      }
      await CloudDocumentService.uploadResumeBytes(
        userId: userId,
        bytes: picked.bytes,
        fileName: picked.fileName,
        source: picked.source,
      );
      setState(() {
        _hasResume = true;
        _resumeName = picked.fileName;
        _uploadDate = CloudDocumentService.labelFor(source);
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported from ${CloudDocumentService.labelFor(source)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _importFromShareLink() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste Google Drive or Dropbox share link',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final file = await CloudDocumentService.importFromShareUrl(url.trim());
      if (file == null) throw Exception('Could not download file');

      final source = url.contains('dropbox')
          ? CloudSource.dropbox
          : CloudSource.googleDrive;

      await CloudDocumentService.uploadResumeBytes(
        userId: userId,
        bytes: file.bytes,
        fileName: file.fileName,
        source: source,
      );
      setState(() {
        _hasResume = true;
        _resumeName = file.fileName;
        _uploadDate = 'Cloud link';
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Link import failed: $e')));
      }
    }
  }

  Future<void> _uploadResume() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.size > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File size must be less than 5MB'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() => _isUploading = true);

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to upload a resume'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      final fileName = '$userId/resume.${file.extension}';

      debugPrint('Uploading resume to resumes bucket: $fileName');
      await Supabase.instance.client.storage
          .from('resumes')
          .uploadBinary(
            fileName,
            file.bytes!,
            fileOptions: const FileOptions(upsert: true),
          );
      debugPrint('Resume uploaded successfully');

      final url = Supabase.instance.client.storage
          .from('resumes')
          .getPublicUrl(fileName);
      debugPrint('Resume public URL: $url');

      await SupabaseService.updateProfile(userId, {
        'resume_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _hasResume = true;
        _resumeName = file.name;
        _uploadDate =
            '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}';
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resume uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
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
                  ? 'Resume upload blocked by storage RLS (403). Check the `resumes` bucket policies.'
                  : 'Failed to upload resume: $details',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Future<void> _deleteResume() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to delete your resume'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Delete the actual file from Supabase Storage
      try {
        // Try to delete resume.pdf, resume.doc, and resume.docx
        for (final ext in ['pdf', 'doc', 'docx']) {
          final fileName = '$userId/resume.$ext';
          try {
            await Supabase.instance.client.storage.from('resumes').remove([
              fileName,
            ]);
            debugPrint('Deleted storage file: $fileName');
          } catch (e) {
            // File might not exist, continue
            debugPrint('Could not delete $fileName: $e');
          }
        }
      } catch (e) {
        debugPrint('Error deleting storage files: $e');
        // Continue anyway - clear the database reference
      }

      // Clear the resume URL from the database
      await SupabaseService.updateProfile(userId, {
        'resume_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      });
      setState(() {
        _hasResume = false;
        _resumeName = null;
        _uploadDate = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resume deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('My Resume')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Resume card ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: _hasResume
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf,
                                color: AppColors.error,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _resumeName ?? 'Resume',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text(context),
                                    ),
                                  ),
                                  Text(
                                    'Uploaded $_uploadDate',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSec(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: _deleteResume,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _uploadResume,
                          icon: const Icon(Icons.upload_outlined),
                          label: const Text('Replace Resume'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.upload_file_outlined,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No resume uploaded yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload your resume to apply for jobs faster',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSec(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadResume,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_outlined),
                          label: Text(
                            _isUploading ? 'Uploading...' : 'Upload Resume',
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud document sync',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import resumes from cloud storage or share links',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSec(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.cloud_outlined, size: 18),
                        label: const Text('Google Drive'),
                        onPressed: _isUploading
                            ? null
                            : () => _importFromCloud(CloudSource.googleDrive),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.cloud_outlined, size: 18),
                        label: const Text('Dropbox'),
                        onPressed: _isUploading
                            ? null
                            : () => _importFromCloud(CloudSource.dropbox),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.cloud_outlined, size: 18),
                        label: const Text('iCloud'),
                        onPressed: _isUploading
                            ? null
                            : () => _importFromCloud(CloudSource.iCloud),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.link, size: 18),
                        label: const Text('Paste link'),
                        onPressed: _isUploading ? null : _importFromShareLink,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAiResume,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating ? 'Generating...' : 'AI generate resume draft',
                ),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resume templates',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Apply a professional template to your draft',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSec(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...ResumeTemplates.templates.map((template) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        template.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.text(context),
                        ),
                      ),
                      subtitle: Text(
                        template.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSec(context),
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          _draftController.text = template.content;
                          _saveDraft();
                        },
                        child: const Text('Use'),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cover letter templates',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ResumeTemplates.coverLetters.map((template) {
                      return ActionChip(
                        label: Text(template.name),
                        onPressed: () {
                          _draftController.text = template.content;
                          _saveDraft();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${template.name} template applied',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Tips section ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Resume Tips',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _Tip(text: 'Keep your resume to 1–2 pages maximum'),
                  _Tip(text: 'Use action verbs to describe your experience'),
                  _Tip(text: 'Include measurable achievements'),
                  _Tip(text: 'Tailor your resume for each job application'),
                  _Tip(
                    text:
                        'Use a clean, professional format for ATS compatibility',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_draftLoaded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bord(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_note_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Resume draft (offline)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved on this device — works without internet',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSec(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _draftController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Notes, summary, or cover letter draft...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await OfflineCacheService.clearResumeDraft();
                              _draftController.clear();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Draft cleared'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveDraft,
                            child: const Text('Save draft'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Supported formats ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bord(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supported formats',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      _FormatChip(label: 'PDF'),
                      SizedBox(width: 8),
                      _FormatChip(label: 'DOCX'),
                      SizedBox(width: 8),
                      _FormatChip(label: 'DOC'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maximum file size: 5MB',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;

  const _Tip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;

  const _FormatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSec(context),
        ),
      ),
    );
  }
}
