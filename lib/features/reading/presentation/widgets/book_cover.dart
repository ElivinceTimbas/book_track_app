import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/book.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    required this.width,
    required this.height,
    this.radius = 4,
  });
  final Book book;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF365749),
      const Color(0xFFB77752),
      const Color(0xFF344967),
      const Color(0xFF85745A),
    ];
    final color =
        colors[book.title.codeUnits.fold<int>(0, (a, b) => a + b) %
            colors.length];
    Widget fallback() => Container(
      color: color,
      padding: EdgeInsets.all(width > 50 ? 10 : 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (width > 50) ...[
            Icon(
              Icons.spa_outlined,
              color: Colors.white.withValues(alpha: .55),
              size: 22,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: editorial(
              width > 50 ? 12 : 5,
              color: const Color(0xFFF4EDD8),
              height: 1.3,
            ),
          ),
          if (width > 50) ...[
            const SizedBox(height: 12),
            Text(
              book.author,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFD8D5C5), fontSize: 7),
            ),
          ],
        ],
      ),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: book.coverUrl.isEmpty
            ? fallback()
            : Image.network(
                book.coverUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => fallback(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback(),
              ),
      ),
    );
  }
}
