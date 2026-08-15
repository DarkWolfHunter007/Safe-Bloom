import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:safe_bloom/features/insights/data/services/article_service.dart';
import 'package:safe_bloom/features/insights/domain/entities/article.dart';
import '../widgets/cycle_charts_widget.dart';

class InsightsView extends StatefulWidget {
  final GlobalKey<CycleChartsWidgetState>? chartsKey;
  const InsightsView({super.key, this.chartsKey});

  @override
  State<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends State<InsightsView> {
  String _selectedCategory = 'All';
  bool _isLoadingArticles = true;
  List<Article> _articles = <Article>[];

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles({bool forceRefresh = false}) async {
    setState(() => _isLoadingArticles = true);
    try {
      final List<Article> fetched = await ArticleService.instance.getArticles(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _articles = List<Article>.from(fetched);
          _isLoadingArticles = false;
        });
        if (forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Articles refreshed live from Gist!'),
              duration: Duration(seconds: 2),
              backgroundColor: AppColors.dropCoral,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _articles = List<Article>.from(ArticleService.fallbackArticles);
          _isLoadingArticles = false;
        });
      }
    }
  }

  void _showArticleDetails(Article article) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.lightCardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                      article.category.toUpperCase(),
                      style: AppTypography.brandTagline(color: Colors.white, fontSize: 9),
                    ),
                  ),
                  Text(
                    article.readTime,
                    style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(article.title, style: AppTypography.brandTitle(fontSize: 24)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'SYNCED WITH YOUR ${article.phase.toUpperCase()} PHASE',
                style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                article.content,
                style: AppTypography.body(fontSize: 14, color: AppColors.textMain),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dropCoral,
                      side: const BorderSide(color: AppColors.dropCoral),
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(article.sourceUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16, color: AppColors.dropCoral),
                    label: Text(
                      'READ FULL ARTICLE ON WEB',
                      style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
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
        : _articles.where((a) => a.category == _selectedCategory).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health & Insights Library', style: AppTypography.brandTitle(fontSize: 28)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'CYCLE-SYNCED KNOWLEDGE & TREND VISUALIZATIONS',
            style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 9),
          ),
          const SizedBox(height: AppSpacing.md),

          // Interactive Cycle & Symptom Charts Card
          CycleChartsWidget(key: widget.chartsKey),

          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cycle-Synced Articles', style: AppTypography.brandTitle(fontSize: 22)),
              IconButton(
                icon: const Icon(Icons.sync, color: AppColors.dropCoral, size: 20),
                tooltip: 'Sync latest articles from web',
                onPressed: () => _loadArticles(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

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

          if (_isLoadingArticles)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.dropCoral),
              ),
            )
          else if (filteredArticles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  'No articles found for $_selectedCategory',
                  style: AppTypography.body(color: AppColors.textMuted),
                ),
              ),
            )
          else
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
                      color: Colors.black.withValues(alpha: 0.02),
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
                                color: AppColors.petalRose.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                article.category.toUpperCase(),
                                style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 9),
                              ),
                            ),
                            Text(
                              article.readTime,
                              style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(article.title, style: AppTypography.brandTitle(fontSize: 18)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          article.content,
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
