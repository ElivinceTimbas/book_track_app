import 'book.dart';

class ReadingFeed {
  ReadingFeed({
    required this.url,
    required this.name,
    required List<Book> books,
    required this.syncedAt,
  }) : books = List.unmodifiable(books);

  final String url;
  final String name;
  final List<Book> books;
  final DateTime syncedAt;
}
