import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/insights/data/services/article_service.dart';
import 'package:safe_bloom/features/insights/domain/entities/article.dart';

void main() {
  group('Article and ArticleService Thorough Tests', () {
    test('Article deserializes accurately from valid JSON map with all fields', () {
      final map = {
        'id': 'art-follicular-energy',
        'title': 'Harnessing Follicular Phase Energy',
        'category': 'Hormones',
        'readTime': '4 min read',
        'phase': 'Follicular',
        'content': 'During the follicular phase, estrogen begins to climb...',
        'sourceUrl': 'https://safebloom.app/articles/follicular',
        'imageUrl': null,
        'version': 2,
        'updatedAt': '2026-08-01',
      };

      final article = Article.fromMap(map);
      expect(article.id, equals('art-follicular-energy'));
      expect(article.title, equals('Harnessing Follicular Phase Energy'));
      expect(article.category, equals('Hormones'));
      expect(article.readTime, equals('4 min read'));
      expect(article.phase, equals('Follicular'));
      expect(article.version, equals(2));
      expect(article.sourceUrl, equals('https://safebloom.app/articles/follicular'));
      expect(article.updatedAt, equals('2026-08-01'));
    });

    test('Article deserialization handles missing optional fields gracefully', () {
      final map = {
        'title': 'Simple Guide',
        'content': 'Content body',
      };

      final article = Article.fromMap(map);
      expect(article.id, isNotEmpty);
      expect(article.title, equals('Simple Guide'));
      expect(article.category, equals('General'));
      expect(article.readTime, equals('3 min read'));
      expect(article.phase, equals('All'));
      expect(article.version, equals(1));
      expect(article.sourceUrl, isNull);
    });

    test('Article serialization toMap produces exact matching dictionary', () {
      final article = Article(
        id: 'test-id',
        title: 'Test Title',
        category: 'Wellness',
        readTime: '5 min read',
        phase: 'Luteal',
        content: 'Test content body',
        version: 3,
        sourceUrl: 'https://safebloom.app/test',
        updatedAt: '2026-08-17',
      );

      final map = article.toMap();
      expect(map['id'], equals('test-id'));
      expect(map['title'], equals('Test Title'));
      expect(map['category'], equals('Wellness'));
      expect(map['readTime'], equals('5 min read'));
      expect(map['phase'], equals('Luteal'));
      expect(map['content'], equals('Test content body'));
      expect(map['version'], equals(3));
      expect(map['sourceUrl'], equals('https://safebloom.app/test'));
    });

    test('Malformed or invalid JSON list parsing is safely filtered', () {
      const malformedJsonString = '[{"invalid": "data"}, {"id": "valid-1", "title": "Valid Article", "category": "Nutrition", "readTime": "2 min", "phase": "All", "content": "Sample"}]';
      final List<dynamic> jsonList = jsonDecode(malformedJsonString);

      final List<Article> parsed = [];
      for (final item in jsonList) {
        try {
          if (item is Map<String, dynamic> && item.containsKey('id') && item.containsKey('title')) {
            parsed.add(Article.fromMap(item));
          }
        } catch (_) {}
      }

      expect(parsed.length, equals(1));
      expect(parsed.first.id, equals('valid-1'));
      expect(parsed.first.title, equals('Valid Article'));
    });

    test('ArticleService markArticleAsRead and getReadArticleVersions persist and retrieve read states', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final Map<String, String> mockStorage = {};

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          final args = call.arguments as Map<dynamic, dynamic>?;
          final key = args?['key'] as String?;
          final value = args?['value'] as String?;
          switch (call.method) {
            case 'read':
              return mockStorage[key];
            case 'write':
              if (key != null && value != null) mockStorage[key] = value;
              return null;
            case 'delete':
              if (key != null) mockStorage.remove(key);
              return null;
            case 'readAll':
              return mockStorage;
            default:
              return null;
          }
        },
      );

      // Initially empty
      final initial = await ArticleService.instance.getReadArticleVersions();
      expect(initial, isEmpty);

      // Mark article 1 as read at version 2
      await ArticleService.instance.markArticleAsRead('art-follicular-energy', 2);
      final after1 = await ArticleService.instance.getReadArticleVersions();
      expect(after1['art-follicular-energy'], equals(2));

      // Mark article 2 as read at version 1
      await ArticleService.instance.markArticleAsRead('art-luteal-pms', 1);
      final after2 = await ArticleService.instance.getReadArticleVersions();
      expect(after2['art-follicular-energy'], equals(2));
      expect(after2['art-luteal-pms'], equals(1));
    });

    test('ArticleService isCacheStale returns false for fresh cache and true for stale cache', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final Map<String, String> mockStorage = {};

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          final args = call.arguments as Map<dynamic, dynamic>?;
          final key = args?['key'] as String?;
          final value = args?['value'] as String?;
          switch (call.method) {
            case 'read':
              return mockStorage[key];
            case 'write':
              if (key != null && value != null) mockStorage[key] = value;
              return null;
            default:
              return null;
          }
        },
      );

      // 1. No timestamp -> stale
      expect(await ArticleService.instance.isCacheStale(), isTrue);

      // 2. Fresh timestamp (2 hours ago) -> not stale
      mockStorage['last_articles_fetch_timestamp'] =
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
      expect(await ArticleService.instance.isCacheStale(), isFalse);

      // 3. Stale timestamp (26 hours ago) -> stale
      mockStorage['last_articles_fetch_timestamp'] =
          DateTime.now().subtract(const Duration(hours: 26)).toIso8601String();
      expect(await ArticleService.instance.isCacheStale(), isTrue);
    });
  });
}
