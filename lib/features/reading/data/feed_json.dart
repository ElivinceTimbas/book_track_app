import '../domain/book.dart';
import '../domain/reading_feed.dart';

// Keep the v1 keys, enum names, nullable fields and ISO date encoding compatible
// with shelves saved before the architecture split.
Map<String, dynamic> bookToJson(Book book) => {
  'id': book.id,
  'title': book.title,
  'author': book.author,
  'coverUrl': book.coverUrl,
  'status': book.status.name,
  'pages': book.pages,
  'rating': book.rating,
  'readAt': book.readAt?.toIso8601String(),
  'startedAt': book.startedAt?.toIso8601String(),
  'addedAt': book.addedAt?.toIso8601String(),
};

Book bookFromJson(Map<String, dynamic> json) => Book(
  id: json['id'] as String,
  title: json['title'] as String,
  author: json['author'] as String,
  coverUrl: json['coverUrl'] as String? ?? '',
  status: ReadingStatus.values.byName(json['status'] as String),
  pages: json['pages'] as int? ?? 0,
  rating: json['rating'] as int? ?? 0,
  readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
  startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
  addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
);

Map<String, dynamic> feedToJson(ReadingFeed feed) => {
  'url': feed.url,
  'name': feed.name,
  'books': feed.books.map(bookToJson).toList(),
  'syncedAt': feed.syncedAt.toIso8601String(),
};

ReadingFeed feedFromJson(Map<String, dynamic> json) => ReadingFeed(
  url: json['url'] as String,
  name: json['name'] as String,
  books: (json['books'] as List)
      .map((book) => bookFromJson(Map<String, dynamic>.from(book as Map)))
      .toList(),
  syncedAt: DateTime.parse(json['syncedAt'] as String),
);
