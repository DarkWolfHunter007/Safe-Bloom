import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/insights/data/services/article_service.dart';
import 'package:safe_bloom/features/insights/domain/entities/article.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Article.fromMap correctly parses JSON map', () {
    final map = {
      'id': 'test_1',
      'title': 'Test Article Title',
      'category': 'Fitness',
      'readTime': '4 min read',
      'phase': 'Follicular',
      'content': 'Test article content text.',
      'sourceUrl': 'https://example.com/test',
    };

    final article = Article.fromMap(map);

    expect(article.id, equals('test_1'));
    expect(article.title, equals('Test Article Title'));
    expect(article.category, equals('Fitness'));
    expect(article.readTime, equals('4 min read'));
    expect(article.phase, equals('Follicular'));
    expect(article.content, equals('Test article content text.'));
    expect(article.sourceUrl, equals('https://example.com/test'));
  });

  test('ArticleService fallback articles are available offline', () async {
    final articles = await ArticleService.instance.getArticles();
    expect(articles, isNotEmpty);
    expect(articles.first.title, isNotEmpty);
  });
}
