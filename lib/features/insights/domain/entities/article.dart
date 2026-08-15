class Article {
  final String id;
  final String title;
  final String category;
  final String readTime;
  final String phase; // 'Menstrual', 'Follicular', 'Ovulation', 'Luteal', 'All'
  final String content;
  final String? sourceUrl;
  final String? imageUrl;

  Article({
    required this.id,
    required this.title,
    required this.category,
    required this.readTime,
    required this.phase,
    required this.content,
    this.sourceUrl,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'readTime': readTime,
      'phase': phase,
      'content': content,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
    };
  }

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id']?.toString() ?? map['title'].hashCode.toString(),
      title: map['title'] ?? '',
      category: map['category'] ?? 'General',
      readTime: map['readTime'] ?? map['read_time'] ?? '3 min read',
      phase: map['phase'] ?? 'All',
      content: map['content'] ?? '',
      sourceUrl: map['sourceUrl'] ?? map['source_url'],
      imageUrl: map['imageUrl'] ?? map['image_url'],
    );
  }
}
