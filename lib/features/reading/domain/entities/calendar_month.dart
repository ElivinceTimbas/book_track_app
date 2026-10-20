import 'book.dart';

enum CalendarEvent {
  finished('Finished'),
  started('Started'),
  shelfDate('Shelf date');

  const CalendarEvent(this.label);
  final String label;

  static CalendarEvent? of(Book book) => book.calendarDate == null
      ? null
      : book.readAt != null
      ? finished
      : book.startedAt != null
      ? started
      : shelfDate;
}

class CalendarMonth {
  CalendarMonth(DateTime viewedMonth, Iterable<Book> mergedBooks)
    : month = DateTime(viewedMonth.year, viewedMonth.month),
      books = List.unmodifiable(
        mergedBooks.where((book) {
          final date = book.calendarDate;
          return date != null &&
              date.year == viewedMonth.year &&
              date.month == viewedMonth.month;
        }).toList()..sort(compareBooks),
      );

  final DateTime month;
  final List<Book> books;
  late final _counts = _countEvents();

  Map<int, Map<CalendarEvent, int>> _countEvents() {
    final counts = <int, Map<CalendarEvent, int>>{};
    for (final book in books) {
      final day = counts.putIfAbsent(book.calendarDate!.day, () => {});
      day.update(
        CalendarEvent.of(book)!,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  int get maxEventCategories =>
      _counts.values.fold(0, (max, day) => day.length > max ? day.length : max);
  int get maxEventCount => _counts.values
      .expand((day) => day.values)
      .fold(0, (max, count) => count > max ? count : max);

  int get leadingDays => month.weekday - DateTime.monday;
  int get days => DateTime(month.year, month.month + 1, 0).day;
  int get weeks => ((leadingDays + days) / 7).ceil();
  String get fileName =>
      'folio-${month.year}-${month.month.toString().padLeft(2, '0')}.png';

  List<Book> onDay(int day) =>
      books.where((book) => book.calendarDate!.day == day).toList();

  static int compareBooks(Book a, Book b) {
    final day = a.calendarDate!.day.compareTo(b.calendarDate!.day);
    if (day != 0) return day;
    final event = CalendarEvent.of(a)!.index
        .compareTo(CalendarEvent.of(b)!.index);
    if (event != 0) return event;
    final title = a.title.compareTo(b.title);
    return title != 0 ? title : a.id.compareTo(b.id);
  }
}
