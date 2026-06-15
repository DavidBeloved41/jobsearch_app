import 'package:flutter/material.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/company_logo.dart';

class CompanyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> company;
  final String? industry;

  const CompanyDetailScreen({
    super.key,
    required this.company,
    this.industry,
  });

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _growthPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final companyId = widget.company['id'] as String? ?? '';
    if (companyId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final reviews = await SupabaseService.getCompanyReviews(companyId);
    final growth = await SupabaseService.getCompanyGrowthPath(
      companyId,
      industry: widget.industry ?? widget.company['industry'] as String?,
    );

    if (mounted) {
      setState(() {
        _reviews = reviews;
        _growthPath = growth;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.company['name'] as String? ?? 'Company';
    final rating = widget.company['average_rating'];
    final ratingText = rating != null ? rating.toString() : 'N/A';
    final website = widget.company['website'] as String?;
    final description = widget.company['description'] as String?;
    final industry =
        widget.industry ?? widget.company['industry'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Company Insights')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.bord(context)),
                    ),
                    child: Column(
                      children: [
                        CompanyLogo(
                          logoUrl: widget.company['logo_url'] as String?,
                          size: 72,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (industry.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            industry,
                            style: TextStyle(
                              color: AppColors.textSec(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$ratingText / 5.0',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.text(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${_reviews.length} reviews)',
                              style: TextStyle(
                                color: AppColors.textSec(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (website != null && website.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            website,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'About',
                      child: Text(
                        description,
                        style: TextStyle(
                          color: AppColors.textSec(context),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                  if (_growthPath != null) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Growth Path',
                      child: Column(
                        children: [
                          _GrowthRow(
                            label: 'Promotion timeline',
                            value:
                                _growthPath!['promotion_timeline'] as String? ??
                                    '',
                          ),
                          _GrowthRow(
                            label: 'Company growth',
                            value: _growthPath!['growth_rate'] as String? ?? '',
                          ),
                          _GrowthRow(
                            label: 'Internal mobility',
                            value:
                                _growthPath!['internal_mobility'] as String? ??
                                    '',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ((_growthPath!['levels'] as List?) ?? [])
                                .map(
                                  (level) => Chip(
                                    label: Text(
                                      level.toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.08),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Employee Reviews',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._reviews.map((review) {
                    final stars = review['rating'] as int? ?? 4;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.bord(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < stars ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormatter.relative(
                                  review['created_at'] as String? ?? '',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSec(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            review['title'] as String? ?? 'Review',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            review['review_text'] as String? ?? '',
                            style: TextStyle(
                              color: AppColors.textSec(context),
                              height: 1.5,
                            ),
                          ),
                          if (review['reviewer_role'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              review['reviewer_role'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSec(context),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _GrowthRow extends StatelessWidget {
  final String label;
  final String value;

  const _GrowthRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSec(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
