import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:safe_bloom/core/services/local_notification_service.dart';
import 'package:safe_bloom/core/services/secure_storage_service.dart';
import '../../domain/entities/article.dart';

class ArticleService {
  static final ArticleService instance = ArticleService._init();
  final FlutterSecureStorage _secureStorage = SafeBloomSecureStorage.instance;

  static const String _cacheKey = 'cached_insights_articles';
  static const String _lastFetchKey = 'last_articles_fetch_timestamp';
  static const String _readArticleVersionsKey = 'read_article_versions_json';
  static const String _knownArticleIdsKey = 'known_article_ids_json';

  /// Public or Secret Raw Gist / JSON feed URL for dynamic daily articles.
  static String feedUrl =
      'https://gist.githubusercontent.com/DarkWolfHunter007/7e69dbfcc1f5e5ef06662d0e7eeed7a4/raw/articles_feed.json';

  ArticleService._init();

  /// Loads the curated offline library directly from the bundled asset.
  Future<List<Article>> loadBundledArticles() async {
    try {
      final jsonString = await rootBundle.loadString('assets/articles_feed.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return List<Article>.from(
        jsonList.map((item) => Article.fromMap(Map<String, dynamic>.from(item))),
      );
    } catch (e) {
      debugPrint('Error loading bundled articles: $e');
      return [];
    }
  }

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

  /// Fetches articles from Gist/Remote JSON feed with 24-hour auto-refresh & local cache/asset fallback.
  Future<List<Article>> getArticles({
    String? customFeedUrl,
    bool forceRefresh = false,
  }) async {
    final targetUrl = customFeedUrl ?? feedUrl;
    final stale = await isCacheStale();

    // 1. Try remote fetch if forced OR if 24 hours have passed since last update
    if (forceRefresh || stale) {
      try {
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
            // Check for new articles and trigger notification
            await _detectAndNotifyNewArticles(articles);

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
        if (forceRefresh) {
          rethrow;
        }
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

    // 3. Fallback to bundled asset library
    final bundled = await loadBundledArticles();
    if (bundled.isNotEmpty) {
      // Seed known IDs if not already present
      try {
        final known = await _secureStorage.read(key: _knownArticleIdsKey);
        if (known == null) {
          await _secureStorage.write(
            key: _knownArticleIdsKey,
            value: jsonEncode(bundled.map((a) => a.id).toList()),
          );
        }
      } catch (_) {}
    }
    return bundled;
  }

  /// Compares incoming articles against known IDs and triggers notification if new guides are found.
  Future<void> _detectAndNotifyNewArticles(List<Article> incoming) async {
    try {
      final knownJson = await _secureStorage.read(key: _knownArticleIdsKey);
      if (knownJson != null && knownJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(knownJson);
        final Set<String> knownIds = list.map((e) => e.toString()).toSet();

        final newArticles = incoming.where((a) => !knownIds.contains(a.id)).toList();
        if (newArticles.isNotEmpty) {
          final titles = newArticles.map((a) => a.title).toList();
          await LocalNotificationService.instance.notifyNewArticles(titles);
        }

        final updatedSet = knownIds.union(incoming.map((a) => a.id).toSet());
        await _secureStorage.write(
          key: _knownArticleIdsKey,
          value: jsonEncode(updatedSet.toList()),
        );
      } else {
        // First run — seed all current IDs without spamming notifications
        await _secureStorage.write(
          key: _knownArticleIdsKey,
          value: jsonEncode(incoming.map((a) => a.id).toList()),
        );
      }
    } catch (e) {
      debugPrint('Error detecting new articles for notification: $e');
    }
  }

  /// Returns map of article ID to the version number the user has read
  Future<Map<String, int>> getReadArticleVersions() async {
    try {
      final jsonStr = await _secureStorage.read(key: _readArticleVersionsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return map.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 1));
      }
    } catch (e) {
      debugPrint('Error reading read article versions: $e');
    }
    return {};
  }

  /// Marks an article ID as read at a specific version in local secure storage
  Future<void> markArticleAsRead(String articleId, [int version = 1]) async {
    try {
      final current = await getReadArticleVersions();
      current[articleId] = version;
      await _secureStorage.write(
        key: _readArticleVersionsKey,
        value: jsonEncode(current),
      );
    } catch (e) {
      debugPrint('Error marking article read: $e');
    }
  }
}
