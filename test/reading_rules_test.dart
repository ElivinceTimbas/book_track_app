import 'package:book_track_app/features/reading/domain/entities/book.dart';
import 'package:book_track_app/features/reading/domain/usecases/reading_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_fakes.dart';

void main() {
  test('Calendar date precedence is finished, started, then added regardless of status', () {
    final read = DateTime(2025, 5, 9);
    final started = DateTime(2025, 5, 3);
    final added = DateTime(2025, 4, 1);
    expect(
      sampleBook(readAt: read, startedAt: started, addedAt: added).calendarDate,
      read,
    );
    expect(
      sampleBook(startedAt: started, addedAt: added).calendarDate,
      started,
    );
    expect(sampleBook(addedAt: added).calendarDate, added);
    expect(sampleBook().calendarDate, isNull);
  });

  test(
    'Higher status replaces even a dated lower-status book with an undated one',
    () {
      final old = sampleBook(
        status: ReadingStatus.reading,
        startedAt: DateTime(2025),
      );
      final candidate = sampleBook(status: ReadingStatus.finished);
      expect(
        mergeBooks([
          sampleFeed(books: [old]),
          sampleFeed(books: [candidate]),
        ]),
        [same(candidate)],
      );
    },
  );

  test(
    'Dated candidate replaces undated existing book even with lower status',
    () {
      final old = sampleBook(status: ReadingStatus.finished);
      final candidate = sampleBook(
        status: ReadingStatus.toRead,
        addedAt: DateTime(2025),
      );
      expect(
        mergeBooks([
          sampleFeed(books: [old, candidate]),
        ]),
        [same(candidate)],
      );
    },
  );

  test(
    'Equal-status dated duplicates keep the first feed, not the latest date',
    () {
      final first = sampleBook(addedAt: DateTime(2024));
      final later = sampleBook(addedAt: DateTime(2026));
      expect(
        mergeBooks([
          sampleFeed(books: [first]),
          sampleFeed(books: [later]),
        ]),
        [same(first)],
      );
      expect(
        mergeBooks([
          sampleFeed(books: [later]),
          sampleFeed(books: [first]),
        ]),
        [same(later)],
      );
    },
  );

  test('Identity is by ID, library retains undated books and sorts descending dates', () {
    final undated = sampleBook(id: 'undated');
    final newer = sampleBook(id: 'newer', addedAt: DateTime(2025, 5, 7));
    final older = sampleBook(id: 'older', addedAt: DateTime(2025, 5, 1));
    final books = mergeBooks([
      sampleFeed(books: [undated, older, newer]),
    ]);
    expect(books, [same(newer), same(older), same(undated)]);
    expect(() => books.clear(), throwsUnsupportedError);
  });

  test('Feed books are defensive immutable snapshots', () {
    final input = [sampleBook()];
    final feed = sampleFeed(books: input);
    input.clear();
    expect(feed.books, hasLength(1));
    expect(() => feed.books.clear(), throwsUnsupportedError);
  });
}
