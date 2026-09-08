import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/job_filters.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

class JobFiltersSheet extends StatefulWidget {
  final JobFilters initialFilters;

  const JobFiltersSheet({super.key, required this.initialFilters});

  @override
  State<JobFiltersSheet> createState() => _JobFiltersSheetState();
}

class _JobFiltersSheetState extends State<JobFiltersSheet> {
  late JobFilters _filters;
  final _locationController = TextEditingController();
  final _industryController = TextEditingController();
  final _techStackController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();
  List<String> _industries = [];
  bool _loadingIndustries = true;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _locationController.text = _filters.location;
    _industryController.text = _filters.industry;
    _techStackController.text = _filters.techStack;
    if (_filters.minSalary != null) {
      _minSalaryController.text = '${_filters.minSalary}';
    }
    if (_filters.maxSalary != null) {
      _maxSalaryController.text = '${_filters.maxSalary}';
    }
    _loadIndustries();
  }

  Future<void> _loadIndustries() async {
    try {
      final list = await SupabaseService.getDistinctIndustries();
      if (mounted) {
        setState(() {
          _industries = list;
          _loadingIndustries = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingIndustries = false);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _industryController.dispose();
    _techStackController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    super.dispose();
  }

  void _apply() {
    final min = int.tryParse(_minSalaryController.text.trim());
    final max = int.tryParse(_maxSalaryController.text.trim());
    Navigator.pop(
      context,
      _filters.copyWith(
        location: _locationController.text.trim(),
        industry: _industryController.text.trim(),
        techStack: _techStackController.text.trim(),
        minSalary: min,
        maxSalary: max,
        clearMinSalary: _minSalaryController.text.trim().isEmpty,
        clearMaxSalary: _maxSalaryController.text.trim().isEmpty,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _filters = const JobFilters();
      _locationController.clear();
      _industryController.clear();
      _techStackController.clear();
      _minSalaryController.clear();
      _maxSalaryController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Advanced filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Work model',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSec(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in ['all', 'remote', 'hybrid', 'on-site'])
                  ChoiceChip(
                    label: Text(option == 'all' ? 'Any' : option),
                    selected: _filters.workModel == option,
                    onSelected: (_) => setState(
                      () => _filters = _filters.copyWith(workModel: option),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Employment type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSec(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in ['all', 'full-time', 'contract'])
                  ChoiceChip(
                    label: Text(option == 'all' ? 'Any' : option),
                    selected: _filters.employmentType == option,
                    onSelected: (_) => setState(
                      () =>
                          _filters = _filters.copyWith(employmentType: option),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Salary range (GHS / year)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSec(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minSalaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Min',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxSalaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Max',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. London, New York',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            if (_industries.isNotEmpty && !_loadingIndustries)
              Autocomplete<String>(
                optionsBuilder: (text) {
                  if (text.text.isEmpty) return _industries;
                  return _industries.where(
                    (i) => i.toLowerCase().contains(text.text.toLowerCase()),
                  );
                },
                onSelected: (v) => _industryController.text = v,
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  if (controller.text.isEmpty &&
                      _industryController.text.isNotEmpty) {
                    controller.text = _industryController.text;
                  }
                  controller.addListener(() {
                    _industryController.text = controller.text;
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Industry',
                      hintText: 'e.g. Technology, Finance',
                      prefixIcon: Icon(Icons.domain_outlined),
                    ),
                  );
                },
              )
            else
              TextField(
                controller: _industryController,
                decoration: const InputDecoration(
                  labelText: 'Industry',
                  prefixIcon: Icon(Icons.domain_outlined),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _techStackController,
              decoration: const InputDecoration(
                labelText: 'Tech stack / skill',
                hintText: 'e.g. Flutter, Python, React',
                prefixIcon: Icon(Icons.code_outlined),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _apply,
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
