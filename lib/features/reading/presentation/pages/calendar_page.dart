import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/calendar_month.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_metadata.dart';
import '../widgets/calendar_event_badge.dart';
import '../widgets/dialogs/share_month_dialog.dart';
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
    this.onShareMonth,
  });

  final List<Book> allBooks;
  final DateTime month;
  final DateTime? selectedDay;
  final bool hasFeeds;
  final VoidCallback onConnect;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime?> onDaySelected;
  final ValueChanged<Book> onBook;
  final ValueChanged<CalendarMonth>? onShareMonth;

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
            final calendar = calendarCard(context);
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
        Row(children: [Icon(icon, size: 17, color: olive)]),
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

  Widget calendarCard(BuildContext context) => Container(
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
        LayoutBuilder(
          builder: (context, constraints) {
            final snapshot = CalendarMonth(month, allBooks);
            final first = snapshot.month;
            final start = DateTime(first.year, first.month, 2 - first.weekday);
            final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
            final counter = TextPainter(
              text: TextSpan(
                text: '${snapshot.maxEventCount}',
                style: DefaultTextStyle.of(context).style
                    .copyWith(fontSize: 13),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final countWidth = counter.width.ceilToDouble() + 2;
            counter.dispose();
            final gridWidth = math.max(
              constraints.maxWidth,
              20.0 + 7 * (10 + math.max(24 * scale, countWidth)),
            );
            final stackMarkers = (gridWidth - 20) / 7 - 10 < 21 + countWidth;
            final dayHeight = math.max(
              68.0,
              14 +
                  24 * scale +
                  snapshot.maxEventCategories *
                      (stackMarkers ? 22 + 20 * scale : 22 * scale),
            );
            return Column(
              children: [
                if (gridWidth > constraints.maxWidth)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'Scroll calendar sideways for larger text.',
                      style: TextStyle(fontSize: 13, color: ink),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridWidth,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Column(
                            children: [
                              for (var row = 0; row < snapshot.weeks; row++)
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
                                          stackMarkers,
                                          scale,
                                          dayHeight,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: const CalendarLegend(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final action = OutlinedButton.icon(
                onPressed: () {
                  final snapshot = CalendarMonth(month, allBooks);
                  if (onShareMonth case final callback?) {
                    callback(snapshot);
                  } else {
                    showShareMonth(context, snapshot);
                  }
                },
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share month'),
              );
              return constraints.maxWidth < 450
                  ? SizedBox(width: double.infinity, child: action)
                  : Align(alignment: Alignment.centerRight, child: action);
            },
          ),
        ),
      ],
    ),
  );

  Widget dayCell(
    DateTime date,
    bool stackMarkers,
    double scale,
    double height,
  ) {
    final current = date.month == month.month;
    final today = DateUtils.isSameDay(date, DateTime.now());
    final selected = DateUtils.isSameDay(date, selectedDay);
    final books = allBooks
        .where((book) => DateUtils.isSameDay(book.calendarDate, date))
        .toList();
    final counts = {
      for (final event in CalendarEvent.values)
        event: books.where((book) => CalendarEvent.of(book) == event).length,
    };
    void select() {
      if (!current) onMonthChanged(DateTime(date.year, date.month));
      onDaySelected(selected ? null : date);
    }

    return Semantics(
      label:
          '${DateFormat.yMMMMd().format(date)}, ${books.length} reading events'
          '${counts.entries.where((entry) => entry.value > 0).map((entry) => ', ${entry.key.label}: ${entry.value}').join()}',
      selected: selected,
      button: true,
      excludeSemantics: true,
      onTap: select,
      child: InkWell(
        onTap: select,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
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
                width: 24 * scale,
                height: 24 * scale,
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
                for (final entry in counts.entries.where(
                  (entry) => entry.value > 0,
                ))
                  stackMarkers
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.key.icon,
                              size: 18,
                              color: entry.key.color,
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(fontSize: 13, color: ink),
                            ),
                          ],
                        )
                      : CalendarEventBadge(
                          entry.key,
                          count: entry.value,
                          label: false,
                        ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
            Expanded(child: Eyebrow('ON YOUR NIGHTSTAND')),
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
            Expanded(child: Eyebrow('A GENTLE REMINDER')),
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
              Flexible(
                child: Text(
                  '${books.length} ${books.length == 1 ? 'moment' : 'moments'} this month',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
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
                    if (CalendarEvent.of(book) case final event?)
                      CalendarEventBadge(event),
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
