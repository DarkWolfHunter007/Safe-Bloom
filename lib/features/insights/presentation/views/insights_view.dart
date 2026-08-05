import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class InsightsView extends StatefulWidget {
  const InsightsView({super.key});

  @override
  State<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends State<InsightsView> {
  String _selectedCategory = 'All';

  final List<Map<String, String>> _articles = const [
    {
      'title': 'Optimizing High-Intensity Workouts in Ovulation',
      'category': 'Fitness',
      'readTime': '3 min read',
      'phase': 'Ovulation',
      'content':
          'During your ovulation window, estrogen peaks along with testosterone. This creates ideal conditions for strength gains, HIIT, and personal records!',
    },
    {
      'title': 'Hormone Balancing Diet & Antioxidants',
      'category': 'Nutrition',
      'readTime': '4 min read',
      'phase': 'Follicular',
      'content':
          'Support follicle development with healthy fats, avocado, salmon, and vibrant berries. Keep hydration high as your body Prepares for ovulation.',
    },
    {
      'title': 'Managing PMS & Luteal Phase Sleep Quality',
      'category': 'Mind & Sleep',
      'readTime': '5 min read',
      'phase': 'Luteal',
      'content':
          'Progesterone rises during the luteal phase, slightly elevating core body temperature. Sleep in a cooler room (65-68°F) to optimize deep REM sleep.',
    },
    {
      'title': 'Iron Replenishment During Your Period',
      'category': 'Nutrition',
      'readTime': '2 min read',
      'phase': 'Menstrual',
      'content':
          'Prioritize iron-rich foods combined with Vitamin C (like spinach with lemon) to support energy during blood loss.',
    },
  ];

  void _showArticleDetails(Map<String, String> article) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.lightCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.dropCoral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      article['category']!.toUpperCase(),
                      style: AppTypography.brandTagline(color: Colors.white, fontSize: 9),
                    ),
                  ),
                  Text(
                    article['readTime']!,
                    style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(article['title']!, style: AppTypography.brandTitle(fontSize: 24)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'SYNCED WITH YOUR ${article['phase']!.toUpperCase()} PHASE',
                style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                article['content']!,
                style: AppTypography.body(fontSize: 14, color: AppColors.textMain),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dropCoral,
                    padding: const EdgeInsets.all(AppSpacing.md),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('CLOSE ARTICLE', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredArticles = _selectedCategory == 'All'
        ? _articles
        : _articles.where((a) => a['category'] == _selectedCategory).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health & Secret Library', style: AppTypography.brandTitle(fontSize: 28)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'CYCLE-SYNCED KNOWLEDGE & EXPERT ADVICE',
            style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 9),
          ),
          const SizedBox(height: AppSpacing.md),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Fitness', 'Nutrition', 'Mind & Sleep'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: AppTypography.body(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppColors.textMain,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.dropCoral,
                    backgroundColor: AppColors.lightCardBackground,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Article Cards List
          ...filteredArticles.map((article) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.lightCardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.lightCardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: InkWell(
                onTap: () => _showArticleDetails(article),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.petalRose.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              article['category']!.toUpperCase(),
                              style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 9),
                            ),
                          ),
                          Text(
                            article['readTime']!,
                            style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(article['title']!, style: AppTypography.brandTitle(fontSize: 18)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        article['content']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
