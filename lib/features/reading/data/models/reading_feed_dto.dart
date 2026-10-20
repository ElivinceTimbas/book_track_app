import '../../domain/entities/reading_feed.dart';
import 'book_dto.dart';

class ReadingFeedDto {
  ReadingFeedDto({
    required this.url,
    required this.name,
    required List<BookDto> books,
    required this.syncedAt,
  }) : books = List.unmodifiable(books);

  final String url;
  final String name;
  final List<BookDto> books;
  final String syncedAt;

  factory ReadingFeedDto.fromJson(Map<String, dynamic> json) => ReadingFeedDto(
    url: json['url'] as String,
    name: json['name'] as String,
    books: (json['books'] as List)
        .map((book) => BookDto.fromJson(Map<String, dynamic>.from(book as Map)))
        .toList(),
    syncedAt: json['syncedAt'] as String,
  );

  factory ReadingFeedDto.fromEntity(ReadingFeed feed) => ReadingFeedDto(
    url: feed.url,
    name: feed.name,
    books: feed.books.map(BookDto.fromEntity).toList(),
    syncedAt: feed.syncedAt.toIso8601String(),
  );

  ReadingFeed toEntity() => ReadingFeed(
    url: url,
    name: name,
    books: books.map((book) => book.toEntity()).toList(),
    syncedAt: DateTime.parse(syncedAt),
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'books': books.map((book) => book.toJson()).toList(),
    'syncedAt': syncedAt,
  };
}
