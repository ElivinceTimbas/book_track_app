import 'package:book_track_app/features/reading/domain/entities/book.dart';
import 'package:book_track_app/features/reading/domain/entities/calendar_month.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_fakes.dart';

void main() {
  test('one actual event per dated book, precedence is independent of shelf status', () {
    final date = DateTime(2024, 2, 29);
    final finished = sampleBook(
      readAt: date,
      startedAt: DateTime(2024, 1),
      addedAt: DateTime(2023),
    );
    final started = sampleBook(
      status: ReadingStatus.finished,
      startedAt: date,
      addedAt: DateTime(2023),
    );
    final shelf = sampleBook(status: ReadingStatus.reading, addedAt: date);
    expect(CalendarEvent.of(finished), CalendarEvent.finished);
    expect(CalendarEvent.of(started), CalendarEvent.started);
    expect(CalendarEvent.of(shelf), CalendarEvent.shelfDate);
    expect(CalendarEvent.of(sampleBook()), isNull);
    expect(CalendarEvent.values.map((event) => event.label), [
      'Finished',
      'Started',
      'Shelf date',
    ]);
    final snapshot = CalendarMonth(DateTime(2024, 2, 20), [
      finished,
      started,
      shelf,
      sampleBook(),
    ]);
    expect(snapshot.books, hasLength(3));
    expect(snapshot.onDay(29), [finished, started, shelf]);
    expect(snapshot.maxEventCategories, 3);
    expect(snapshot.maxEventCount, 1);
    expect(snapshot.onDay(1), isEmpty);
    expect(CalendarMonth(DateTime(2024, 1), [finished]), isA<CalendarMonth>());
    expect(CalendarMonth(DateTime(2024, 1), [finished]).books, isEmpty);
  });

  test('normalize first day, leap year and Monday-first four/five/six-week layouts', () {
    final leap = CalendarMonth(DateTime(2024, 2, 29), []);
    expect(leap.month, DateTime(2024, 2));
    expect((leap.days, leap.leadingDays, leap.weeks), (29, 3, 5));
    final six = CalendarMonth(DateTime(2021, 5, 19), []);
    expect((six.days, six.leadingDays, six.weeks), (31, 5, 6));
    expect(CalendarMonth(DateTime(2021, 2, 19), []).weeks, 4);
    expect(leap.fileName, 'folio-2024-02.png');
  });

  test(
    'snapshot is immutable, deterministic by date, event, title then id',
    () {
      final date = DateTime(2024, 2, 4);
      final source = [
        sampleBook(id: 'z', title: 'B', readAt: date),
        sampleBook(id: 's', title: 'A', startedAt: date),
        sampleBook(id: 'b', title: 'A', readAt: date),
        sampleBook(id: 'a', title: 'A', readAt: date),
        sampleBook(id: 'old', addedAt: DateTime(2024, 1)),
      ];
      final snapshot = CalendarMonth(date, source);
      source.clear();
      expect(snapshot.books.map((book) => book.id), ['a', 'b', 'z', 's']);
      expect(() => snapshot.books.clear(), throwsUnsupportedError);
    },
  );
}
