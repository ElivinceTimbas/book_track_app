import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../domain/book.dart';
import '../book_labels.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_metadata.dart';
import '../widgets/folio_brand.dart';
import '../widgets/page_components.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({
    super.key,
    required this.allBooks,
    required this.month,
    required this.selectedDay,
    required this.hasFeeds,
    required this.onConnect,
    required this.onMonthChanged,
    required this.onDaySelected,
    required this.onBook,
  });

  final List<Book> allBooks;
  final DateTime month;
  final DateTime? selectedDay;
  final bool hasFeeds;
  final VoidCallback onConnect;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime?> onDaySelected;
  final ValueChanged<Book> onBook;

  List<Book> get monthBooks => allBooks.where((book) {
    final date = book.calendarDate;
    return date != null && date.year == month.year && date.month == month.month;
  }).toList()..sort((a, b) => b.calendarDate!.compareTo(a.calendarDate!));

  @override
  Widget build(BuildContext context) {
    final books = monthBooks;
    final finished = books.where((book) => book.readAt != null).length;
    final pages = books
        .where((book) => book.readAt != null)
        .fold<int>(0, (sum, book) => sum + book.pages);
    final reading = allBooks
        .where((book) => book.status == ReadingStatus.reading)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Your reading, at a glance.',
          'Dates from your Goodreads shelf snapshot, not a daily reading log.',
        ),
        const SizedBox(height: 26),
        if (!hasFeeds) ...[
          ConnectBanner(onConnect: onConnect),
          const SizedBox(height: 25),
        ],
        if (hasFeeds && allBooks.isEmpty) ...[
          const EmptyState(
            Icons.rss_feed_rounded,
            'Shelf connected, no books returned.',
            'The RSS snapshot is empty. Refresh later or connect another public shelf.',
          ),
          const SizedBox(height: 20),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: statCard(
                  context,
                  Icons.auto_stories_outlined,
                  '$finished',
                  'Books finished',
                  'this month',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: statCard(
                  context,
                  Icons.menu_book_outlined,
                  NumberFormat.compact().format(pages),
                  'Book pages',
                  'from finished books',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: statCard(
                  context,
                  Icons.bookmark_border_rounded,
                  '${reading.length}',
                  MediaQuery.sizeOf(context).width < 600
                      ? 'Reading now'
                      : 'Currently reading',
                  'one page at a time',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            final calendar = calendarCard();
            final aside = Column(
              children: [
                currentlyReading(reading),
                const SizedBox(height: 18),
                gentleReminder(),
              ],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: calendar),
                  const SizedBox(width: 22),
                  SizedBox(width: 252, child: aside),
                ],
              );
            }
            return Column(
              children: [calendar, const SizedBox(height: 22), aside],
            );
          },
        ),
        const SizedBox(height: 28),
        activitySection(books),
      ],
    );
  }

  Widget statCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    String detail,
  ) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 14 : 19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: olive),
          ],
        ),
        const SizedBox(height: 13),
        Text(value, style: editorial(29)),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        if (MediaQuery.sizeOf(context).width >= 600) ...[
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 10, color: muted)),
        ],
      ],
    ),
  );

  Widget calendarCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: line),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 17, 13, 15),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: editorial(23),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  onMonthChanged(DateTime(now.year, now.month));
                  onDaySelected(now);
                },
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  minimumSize: const Size(45, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Today'),
              ),
              IconButton(
                tooltip: 'Previous month',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left, size: 19),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right, size: 19),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final day in [
                'MON',
                'TUE',
                'WED',
                'THU',
                'FRI',
                'SAT',
                'SUN',
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        LayoutBuilder(
          builder: (context, constraints) {
            final start = DateTime(month.year, month.month, 2 - month.weekday);
            final days = DateTime(month.year, month.month + 1, 0).day;
            final count = ((month.weekday - 1 + days) / 7).ceil() * 7;
            final compact = constraints.maxWidth < 450;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Column(
                children: [
                  for (var row = 0; row < count ~/ 7; row++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child: dayCell(
                              DateTime(
                                start.year,
                                start.month,
                                start.day + row * 7 + col,
                              ),
                              compact,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Wrap(
            spacing: 17,
            runSpacing: 9,
            children: [
              legend('Finished', olive),
              legend('Started', rust),
              legend('Added to shelf', const Color(0xFFA8AD9B)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget dayCell(DateTime date, bool compact) {
    final current = date.month == month.month;
    final today = DateUtils.isSameDay(date, DateTime.now());
    final selected = DateUtils.isSameDay(date, selectedDay);
    final books = allBooks
        .where((book) => DateUtils.isSameDay(book.calendarDate, date))
        .toList();
    return Semantics(
      label:
          '${DateFormat.yMMMMd().format(date)}, ${books.length} reading events',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () {
          if (!current) onMonthChanged(DateTime(date.year, date.month));
          onDaySelected(selected ? null : date);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: compact ? 68 : 89,
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.fromLTRB(3, 5, 3, 4),
          decoration: BoxDecoration(
            color: selected
                ? softOlive
                : books.isNotEmpty && current
                ? const Color(0xFFF8F9F5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: const Color(0xFFA6B199))
                : null,
          ),
          child: Column(
            children: [
              Container(
                width: 23,
                height: 23,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: today ? olive : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: today || books.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: today
                        ? Colors.white
                        : current
                        ? ink
                        : const Color(0xFFCCCEC5),
                  ),
                ),
              ),
              if (books.isNotEmpty && current) ...[
                const SizedBox(height: 4),
                if (!compact)
                  SizedBox(
                    height: 35,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BookCover(
                          book: books.first,
                          width: 23,
                          height: 34,
                          radius: 2,
                        ),
                        if (books.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Text(
                              '+${books.length - 1}',
                              style: const TextStyle(fontSize: 9, color: olive),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  width: compact ? 5 : 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: eventColor(books.first),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: muted, fontSize: 9)),
    ],
  );

  Widget currentlyReading(List<Book> reading) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bookmark_border_rounded, size: 15, color: olive),
            SizedBox(width: 8),
            Eyebrow('ON YOUR NIGHTSTAND'),
          ],
        ),
        const SizedBox(height: 21),
        if (reading.isEmpty)
          const Text(
            'A fresh chapter is waiting. Add a currently-reading shelf to see your books here.',
            style: TextStyle(fontSize: 12, color: muted, height: 1.8),
          )
        else ...[
          Center(
            child: GestureDetector(
              onTap: () => onBook(reading.first),
              child: BookCover(
                book: reading.first,
                width: 92,
                height: 137,
                radius: 4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              reading.first.title,
              textAlign: TextAlign.center,
              style: editorial(19, height: 1.3),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              reading.first.author,
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
          const SizedBox(height: 17),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F0E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_outlined, size: 11, color: rust),
                  SizedBox(width: 5),
                  Text(
                    'In the middle of a good thing',
                    style: TextStyle(fontSize: 9, color: rust),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onBook(reading.first),
              child: const Text('View book', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ],
    ),
  );

  Widget gentleReminder() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EDE5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.wb_sunny_outlined, size: 16, color: rust),
            SizedBox(width: 8),
            Eyebrow('A GENTLE REMINDER'),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          'It’s not about how many.\nIt’s about how it feels.',
          style: editorial(19, height: 1.5),
        ),
        const SizedBox(height: 9),
        const Text(
          'A few pages count, too.',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ],
    ),
  );

  Widget activitySection(List<Book> books) {
    final visible = selectedDay == null
        ? books
        : books
              .where(
                (book) => DateUtils.isSameDay(book.calendarDate, selectedDay),
              )
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedDay == null
                    ? 'Between the pages'
                    : DateFormat('MMMM d').format(selectedDay!),
                style: editorial(24),
              ),
            ),
            if (selectedDay != null)
              TextButton(
                onPressed: () => onDaySelected(null),
                child: const Text(
                  'Whole month',
                  style: TextStyle(fontSize: 11),
                ),
              )
            else
              Text(
                '${books.length} ${books.length == 1 ? 'moment' : 'moments'} this month',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          selectedDay == null
              ? 'The books that made this month a little richer.'
              : 'Your reading moments on this day.',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 17),
        if (visible.isEmpty)
          EmptyState(
            Icons.calendar_today_outlined,
            'A little space for your next chapter.',
            selectedDay == null
                ? 'No reading dates in this month. Try another month or refresh your feeds.'
                : 'No books recorded on this day. Select another day to explore.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 1),
                    ),
                  bookRow(visible[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget bookRow(Book book) => InkWell(
    onTap: () => onBook(book),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          BookCover(book: book, width: 38, height: 55, radius: 3),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: editorial(17),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  book.author,
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          book.readAt != null
                              ? Icons.check_circle_outline_rounded
                              : Icons.bookmark_border_rounded,
                          size: 11,
                          color: eventColor(book),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          book.eventLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: eventColor(book),
                          ),
                        ),
                      ],
                    ),
                    if (book.rating > 0) RatingStars(book.rating),
                  ],
                ),
              ],
            ),
          ),
          if (book.calendarDate != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                DateFormat('MMM d').format(book.calendarDate!),
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 17, color: muted),
        ],
      ),
    ),
  );
}
