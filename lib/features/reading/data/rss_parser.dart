import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../domain/book.dart';
import '../domain/feed_exception.dart';
import '../domain/reading_feed.dart';

/// RSS interpretation is independent of HTTP, persistence and Flutter.
class GoodreadsRssParser {
  GoodreadsRssParser({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;

  ReadingFeed parse(String source, String url) {
    try {
      final document = XmlDocument.parse(source);
      final channel = document.findAllElements('channel').firstOrNull;
      if (channel == null || document.rootElement.name.local != 'rss') {
        throw const FeedException(
          'This link did not return an RSS feed. Copy the RSS link from your Goodreads bookshelf.',
        );
      }
      final shelf = Uri.parse(url).queryParameters['shelf'] ?? '';
      final books = channel.findElements('item').map((item) {
        String value(String name) =>
            item.getElement(name)?.innerText.trim() ?? '';
        final readAt = parseDate(value('user_read_at'));
        final startedAt = parseDate(value('user_started_at'));
        final shelves = '${value('user_shelves')},$shelf'
            .split(',')
            .map((s) => s.trim())
            .toSet();
        final status =
            readAt != null || shelves.contains('read')
            ? ReadingStatus.finished
            : shelves.contains('currently-reading')
            ? ReadingStatus.reading
            : ReadingStatus.toRead;
        final title = value('title').isEmpty ? 'Untitled book' : value('title');
        final author = value('author_name').isEmpty
            ? 'Unknown author'
            : value('author_name');
        final cover =
            [
              value('book_large_image_url'),
              value('book_medium_image_url'),
              value('book_image_url'),
            ].where((value) => value.isNotEmpty).firstOrNull ??
            '';
        final coverUri = Uri.tryParse(cover);
        return Book(
          id: value('book_id').isNotEmpty ? value('book_id') : '$title|$author',
          title: title,
          author: author,
          coverUrl:
              coverUri != null && ['http', 'https'].contains(coverUri.scheme)
              ? coverUri.replace(scheme: 'https').toString()
              : '',
          status: status,
          pages: int.tryParse(value('num_pages')) ?? 0,
          rating: (int.tryParse(value('user_rating')) ?? 0).clamp(0, 5),
          readAt: readAt,
          startedAt: startedAt,
          addedAt:
              parseDate(value('user_date_added')) ??
              parseDate(value('pubDate')),
        );
      }).toList();
      return ReadingFeed(
        url: url,
        name:
            channel.getElement('title')?.innerText.trim() ?? 'Goodreads shelf',
        books: books,
        syncedAt: _now(),
      );
    } on FeedException {
      rethrow;
    } catch (_) {
      throw const FeedException(
        'We couldn’t read this RSS feed. Check that you copied the full public shelf RSS link.',
      );
    }
  }

  static DateTime? parseDate(String source) {
    if (source.isEmpty) return null;
    // Keep the date recorded by Goodreads rather than shifting it to the device's zone.
    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})'
      r'(?:[Tt ](?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d'
      r'(?:\.\d+)?(?:[Zz]|[+-](?:[01]\d|2[0-3]):?[0-5]\d)?)?$',
    ).firstMatch(source);
    if (iso != null && iso.end == source.length) {
      final year = int.parse(iso[1]!);
      final month = int.parse(iso[2]!);
      final day = int.parse(iso[3]!);
      final date = DateTime(year, month, day);
      return date.year == year && date.month == month && date.day == day
          ? date
          : null;
    }
    final withoutZone = source.replaceFirst(
      RegExp(r'\s(?:[+-]\d{4}|GMT|UTC)$'),
      '',
    );
    for (final format in [
      'EEE, dd MMM yyyy HH:mm:ss',
      'EEE, d MMM yyyy HH:mm:ss',
      'EEE MMM dd HH:mm:ss yyyy',
      'MMM dd, yyyy',
    ]) {
      try {
        return DateFormat(format, 'en_US').parseStrict(withoutZone);
      } on FormatException {
        // Goodreads shelf dates and publication dates use different formats.
      }
    }
    return null;
  }
}
