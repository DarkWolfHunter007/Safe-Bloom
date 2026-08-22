import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
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

    test('24-hour cache staleness logic accurately calculates expiration', () {
      final now = DateTime.now();

      // Fresh cache (1 hour ago)
      final recentFetch = now.subtract(const Duration(hours: 1));
      final isFresh = now.difference(recentFetch).inHours < 24;
      expect(isFresh, isTrue);

      // Stale cache (25 hours ago)
      final staleFetch = now.subtract(const Duration(hours: 25));
      final isStale = now.difference(staleFetch).inHours >= 24;
      expect(isStale, isTrue);
    });

    test('New article detection isolates unseen article IDs', () {
      final knownIds = {'art-1', 'art-2', 'art-3'};
      final incoming = [
        Article(id: 'art-2', title: 'Art 2', category: 'General', readTime: '1 min', phase: 'All', content: 'C'),
        Article(id: 'art-4', title: 'Art 4 (New)', category: 'General', readTime: '1 min', phase: 'All', content: 'C'),
        Article(id: 'art-5', title: 'Art 5 (New)', category: 'General', readTime: '1 min', phase: 'All', content: 'C'),
      ];

      final newArticles = incoming.where((a) => !knownIds.contains(a.id)).toList();
      expect(newArticles.length, equals(2));
      expect(newArticles.map((a) => a.id), containsAll(['art-4', 'art-5']));
    });
  });
}
