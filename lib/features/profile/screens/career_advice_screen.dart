import 'package:flutter/material.dart';
import '../../../core/data/career_advice_repository.dart';
import '../../../core/theme/app_colors.dart';

class CareerAdviceScreen extends StatefulWidget {
  const CareerAdviceScreen({super.key});

  @override
  State<CareerAdviceScreen> createState() => _CareerAdviceScreenState();
}

class _CareerAdviceScreenState extends State<CareerAdviceScreen> {
  String _selectedCategory = 'All';

  List<CareerArticle> get _filteredArticles {
    if (_selectedCategory == 'All') return CareerAdviceRepository.articles;
    return CareerAdviceRepository.byCategory(_selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...CareerAdviceRepository.categories];

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Career Advice')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: categories.map((cat) {
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredArticles.length,
              itemBuilder: (context, index) {
                final article = _filteredArticles[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CareerArticleDetailScreen(article: article),
                    ),
                  ),
                  child: Container(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            article.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          article.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          article.summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSec(context),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          article.readTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSec(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CareerArticleDetailScreen extends StatelessWidget {
  final CareerArticle article;

  const CareerArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: Text(article.category)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.readTime,
              style: TextStyle(color: AppColors.textSec(context), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Text(
              article.content,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSec(context),
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
