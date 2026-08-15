import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/article.dart';

class ArticleService {
  static final ArticleService instance = ArticleService._init();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _cacheKey = 'cached_insights_articles';
  static const String _lastFetchKey = 'last_articles_fetch_timestamp';
  
  /// Public or Secret Raw Gist / JSON feed URL for dynamic daily articles.
  static String feedUrl =
      'https://gist.githubusercontent.com/DarkWolfHunter007/7e69dbfcc1f5e5ef06662d0e7eeed7a4/raw/articles_feed.json';

  ArticleService._init();

  /// Default curated built-in articles (fallback offline library)
  static final List<Article> fallbackArticles = <Article>[
    Article(
      id: 'art_ovulation_fitness',
      title: 'Optimizing High-Intensity Workouts in Ovulation',
      category: 'Fitness',
      readTime: '3 min read',
      phase: 'Ovulation',
      content:
          'During your ovulation window, estrogen peaks along with testosterone. This creates ideal conditions for strength gains, HIIT, and personal records! Leverage high energy levels while focusing on proper joint stability.',
      sourceUrl: 'https://www.healthline.com/health/fitness-exercise/cycle-syncing-workout',
    ),
    Article(
      id: 'art_follicular_nutrition',
      title: 'Hormone Balancing Diet & Antioxidants',
      category: 'Nutrition',
      readTime: '4 min read',
      phase: 'Follicular',
      content:
          'Support follicle development with healthy fats, avocado, salmon, and vibrant berries. As your body prepares for ovulation, keep hydration high and include fermented foods like kimchi or kefir for gut health.',
      sourceUrl: 'https://www.medicalnewstoday.com/articles/cycle-syncing-food',
    ),
    Article(
      id: 'art_luteal_sleep',
      title: 'Managing PMS & Luteal Phase Sleep Quality',
      category: 'Mind & Sleep',
      readTime: '5 min read',
      phase: 'Luteal',
      content:
          'Progesterone rises during the luteal phase, slightly elevating core body temperature. Sleep in a cooler room (65–68°F) to optimize deep REM sleep and reduce pre-menstrual restlessness.',
      sourceUrl: 'https://www.sleepfoundation.org/women-sleep/pms-and-sleep',
    ),
    Article(
      id: 'art_menstrual_iron',
      title: 'Iron Replenishment During Your Period',
      category: 'Nutrition',
      readTime: '2 min read',
      phase: 'Menstrual',
      content:
          'Prioritize iron-rich foods combined with Vitamin C (like spinach with lemon juice or lentils with bell peppers) to support energy levels and compensate for menstrual blood loss.',
      sourceUrl: 'https://www.hopkinsmedicine.org/health/wellness-and-prevention/anemia-and-menstruation',
    ),
    Article(
      id: 'art_follicular_creativity',
      title: 'Harnessing High Energy & Brain Focus in Follicular Phase',
      category: 'Mind & Sleep',
      readTime: '3 min read',
      phase: 'Follicular',
      content:
          'Rising estrogen levels during the follicular phase boost brain neuroplasticity and dopamine. Use this phase for planning new projects, brainstorming sessions, and social gatherings.',
    ),
    Article(
      id: 'art_luteal_magnesium',
      title: 'Magnesium & Cramp Relief in Luteal Phase',
      category: 'Nutrition',
      readTime: '4 min read',
      phase: 'Luteal',
      content:
          'Magnesium glycinate or citrate helps relax uterine smooth muscle, relieving pre-period cramps and reducing fluid retention. Include dark chocolate, pumpkin seeds, and leafy greens.',
    ),
  ];

  /// Checks whether local cache is older than 24 hours
  Future<bool> isCacheStale() async {
    try {
      final lastFetchStr = await _secureStorage.read(key: _lastFetchKey);
      if (lastFetchStr == null) return true;
      final lastFetch = DateTime.tryParse(lastFetchStr);
      if (lastFetch == null) return true;
      return DateTime.now().difference(lastFetch).inHours >= 24;
    } catch (_) {
      return true;
    }
  }

  /// Fetches articles from Gist/Remote JSON feed with 24-hour auto-refresh & local cache fallback.
  Future<List<Article>> getArticles({
    String? customFeedUrl,
    bool forceRefresh = false,
  }) async {
    final targetUrl = customFeedUrl ?? feedUrl;
    final stale = await isCacheStale();

    // 1. Try remote fetch if forced OR if 24 hours have passed since last update
    if (forceRefresh || stale) {
      try {
        // Cache-busting query param to bypass GitHub CDN caching on force refresh
        final cacheBustUrl = forceRefresh
            ? '$targetUrl?t=${DateTime.now().millisecondsSinceEpoch}'
            : targetUrl;
        final response = await http
            .get(
              Uri.parse(cacheBustUrl),
              headers: {'Cache-Control': 'no-cache, no-store, must-revalidate'},
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final List<dynamic> jsonList = jsonDecode(response.body);
          final List<Article> articles = List<Article>.from(
            jsonList.map((item) => Article.fromMap(Map<String, dynamic>.from(item))),
          );

          if (articles.isNotEmpty) {
            // Cache successful network payload & timestamp
            await _secureStorage.write(
              key: _cacheKey,
              value: jsonEncode(articles.map((a) => a.toMap()).toList()),
            );
            await _secureStorage.write(
              key: _lastFetchKey,
              value: DateTime.now().toIso8601String(),
            );
            return articles;
          }
        }
      } catch (e) {
        debugPrint('Remote articles fetch failed or timed out ($e). Reading local cache.');
      }
    }

    // 2. Fallback to local secure storage cache
    try {
      final cachedJson = await _secureStorage.read(key: _cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        final List<Article> cachedArticles = List<Article>.from(
          jsonList.map((item) => Article.fromMap(Map<String, dynamic>.from(item))),
        );
        if (cachedArticles.isNotEmpty) {
          return cachedArticles;
        }
      }
    } catch (e) {
      debugPrint('Error reading cached articles: $e');
    }

    // 3. Fallback to built-in curated library
    return List<Article>.from(fallbackArticles);
  }

  static const String _readArticlesKey = 'read_article_ids_json';

  /// Returns set of article IDs that user has read
  Future<Set<String>> getReadArticleIds() async {
    try {
      final jsonStr = await _secureStorage.read(key: _readArticlesKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('Error reading read article IDs: $e');
    }
    return {};
  }

  /// Marks an article ID as read in local secure storage
  Future<void> markArticleAsRead(String articleId) async {
    try {
      final current = await getReadArticleIds();
      if (!current.contains(articleId)) {
        current.add(articleId);
        await _secureStorage.write(
          key: _readArticlesKey,
          value: jsonEncode(current.toList()),
        );
      }
    } catch (e) {
      debugPrint('Error marking article read: $e');
    }
  }
}
