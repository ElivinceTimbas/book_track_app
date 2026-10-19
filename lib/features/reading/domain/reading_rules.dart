import 'book.dart';
import 'reading_feed.dart';

/// Feed order breaks ties. A dated candidate can replace an undated book even
/// when its status has lower priority; these are intentionally OR conditions.
List<Book> mergeBooks(Iterable<ReadingFeed> feeds) {
  final unique = <String, Book>{};
  for (final feed in feeds) {
    for (final book in feed.books) {
      final existing = unique[book.id];
      if (existing == null ||
          book.status.index < existing.status.index ||
          (existing.calendarDate == null && book.calendarDate != null)) {
        unique[book.id] = book;
      }
    }
  }
  final sorted = unique.values.toList()
    ..sort(
      (a, b) => (b.calendarDate ?? DateTime(1900)).compareTo(
        a.calendarDate ?? DateTime(1900),
      ),
    );
  return List.unmodifiable(sorted);
}
