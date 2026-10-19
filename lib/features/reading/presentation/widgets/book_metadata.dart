import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/book.dart';

Color eventColor(Book book) => book.readAt != null
    ? olive
    : book.startedAt != null
    ? rust
    : const Color(0xFFA8AD9B);

class RatingStars extends StatelessWidget {
  const RatingStars(this.rating, {super.key});
  final int rating;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < rating; i++)
        const Icon(Icons.star_rounded, size: 11, color: rust),
    ],
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.book, {super.key});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final label = switch (book.status) {
      ReadingStatus.finished => 'Finished',
      ReadingStatus.reading => 'Currently reading',
      ReadingStatus.toRead => 'Want to read',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: book.status == ReadingStatus.reading
            ? const Color(0xFFF7F0E8)
            : softOlive,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: book.status == ReadingStatus.reading ? rust : olive,
        ),
      ),
    );
  }
}
