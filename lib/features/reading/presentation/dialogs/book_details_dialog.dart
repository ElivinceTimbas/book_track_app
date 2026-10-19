import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../domain/book.dart';
import '../book_labels.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_metadata.dart';

class BookDetailsDialog extends StatelessWidget {
  const BookDetailsDialog({
    super.key,
    required this.book,
  });
  final Book book;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: paper,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Close book details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
            BookCover(book: book, width: 125, height: 185, radius: 5),
            const SizedBox(height: 24),
            Text(book.title, style: editorial(28), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              book.author,
              style: const TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 18),
            StatusBadge(book),
            if (book.rating > 0) ...[
              const SizedBox(height: 15),
              RatingStars(book.rating),
            ],
            const SizedBox(height: 22),
            if (book.pages > 0)
              Text(
                '${book.pages} pages',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            if (book.calendarDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '${book.eventLabel} · ${DateFormat.yMMMd().format(book.calendarDate!)}',
                style: const TextStyle(color: olive, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 22),
            const Text(
              'From your public Goodreads shelf.',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}
