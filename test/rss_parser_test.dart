import 'package:book_track_app/core/errors/feed_exception.dart';
import 'package:book_track_app/features/reading/data/models/rss_parser.dart';
import 'package:book_track_app/features/reading/domain/entities/book.dart';
import 'package:flutter_test/flutter_test.dart';

const url = 'https://www.goodreads.com/review/list_rss/123?shelf=all';

void main() {
  test('Parser retains date formats, shelf day, invalid-date and empty-date behavior', () {
    for (final source in [
      '2025-05-07T23:30:00-07:00',
      'Wed, 07 May 2025 23:30:00 -0700',
      'Wed, 7 May 2025 23:30:00 GMT',
      'Wed May 07 23:30:00 2025',
      'May 07, 2025',
    ]) {
      final parsed = GoodreadsRssParser.parseDate(source)!;
      expect(
        [parsed.year, parsed.month, parsed.day],
        [2025, 5, 7],
        reason: source,
      );
      expect(parsed.isUtc, isFalse);
    }
    expect(GoodreadsRssParser.parseDate(''), isNull);
    expect(GoodreadsRssParser.parseDate('not a date'), isNull);
    for (final invalid in ['2025-02-29', '2024-02-30', '2025-13-01', '2025-00-01', '2025-05-00', '2025-04-31']) {
      expect(GoodreadsRssParser.parseDate(invalid), isNull, reason: invalid);
    }
    expect(GoodreadsRssParser.parseDate('2024-02-29'), DateTime(2024, 2, 29));
  });

  test('Parser preserves status priority, added/pubDate fallback, defaults and cover choice', () {
    final feed = GoodreadsRssParser().parse('''<rss><channel>
      <item><title>Read by date</title><user_shelves>currently-reading</user_shelves><user_read_at>2025-05-07</user_read_at><user_rating>9</user_rating><num_pages>bad</num_pages><book_large_image_url>http://example.com/large</book_large_image_url><book_image_url>https://example.com/small</book_image_url></item>
      <item><book_id>2</book_id><user_shelves>to-read, read</user_shelves><user_rating>-3</user_rating><user_date_added>bad</user_date_added><pubDate>Wed, 07 May 2025 12:00:00 UTC</pubDate><book_medium_image_url>http://example.com/medium</book_medium_image_url></item>
      <item><book_id>3</book_id><user_shelves>currently-reading</user_shelves><user_started_at>2025-05-01</user_started_at><book_image_url>file:///private/cover</book_image_url></item>
      <item><book_id>4</book_id><user_shelves>to-read</user_shelves></item>
    </channel></rss>''', url);
    expect(feed.name, 'Goodreads shelf');
    expect(feed.books.map((book) => book.status), [
      ReadingStatus.finished,
      ReadingStatus.finished,
      ReadingStatus.reading,
      ReadingStatus.toRead,
    ]);
    expect(feed.books.first.id, 'Read by date|Unknown author');
    expect(feed.books.first.rating, 5);
    expect(feed.books.first.pages, 0);
    expect(feed.books.first.coverUrl, 'https://example.com/large');
    expect(feed.books[1].title, 'Untitled book');
    expect(feed.books[1].rating, 0);
    expect(feed.books[1].addedAt, DateTime(2025, 5, 7, 12));
    expect(feed.books[1].coverUrl, 'https://example.com/medium');
    expect(feed.books[2].calendarDate, DateTime(2025, 5, 1));
    expect(feed.books[2].coverUrl, '');
    expect(feed.books.last.calendarDate, isNull);
  });

  test('ISO dates validate complete timestamps without shifting the recorded day', () {
    for (final source in [
      '2025-05-07',
      '2025-05-07T00:00:00',
      '2025-05-07 23:59:59',
      '2025-05-07T23:59:59.123456Z',
      '2025-05-07t23:59:59z',
      '2025-05-07T00:00:00+14:00',
      '2025-05-07T23:59:59-12:00',
      '2025-05-07T00:00:00.5+0530',
      '2025-05-07T23:59:59-07:00',
    ]) {
      final parsed = GoodreadsRssParser.parseDate(source);
      expect(parsed, DateTime(2025, 5, 7), reason: source);
      expect(parsed!.isUtc, isFalse, reason: source);
    }
    expect(
      GoodreadsRssParser.parseDate('2024-02-29T23:59:59Z'),
      DateTime(2024, 2, 29),
    );
  });

  test('ISO dates reject trailing garbage and invalid date, time or offset components', () {
    for (final source in [
      '2025-05-07junk',
      '2025-05-07\njunk',
      '2025-05-07\n',
      '2025-05-07T99:99:99+99:99',
      '2025-05-07T24:00:00Z',
      '2025-05-07T12:60:00Z',
      '2025-05-07T12:00:60Z',
      '2025-05-07T12:00:00+24:00',
      '2025-05-07T12:00:00-24:00',
      '2025-05-07T12:00:00+05:60',
      '2025-05-07T12:00:00-0560',
      '2025-05-07T12:00:00+99:99',
      '2025-05-07T12:00:00Zjunk',
      '2025-05-07T12:00:00Z\n',
      '2025-05-07T12:00',
      '2025-05-07T12:00:00.',
      '2025-05-07T12:00:00+05',
      '2025-05-07T12:00:00+5:30',
      '2025-05-07Z',
      '2025-02-29T12:00:00Z',
      '2025-04-31T12:00:00-07:00',
      '2025-13-01T12:00:00Z',
    ]) {
      expect(GoodreadsRssParser.parseDate(source), isNull, reason: source);
    }
  });

  test('Shelf status uses exact comma tokens in items and shelf queries', () {
    final parser = GoodreadsRssParser();
    for (final (shelves, expected) in [
      ('currently-reading', ReadingStatus.reading),
      ('favorites, currently-reading , fiction', ReadingStatus.reading),
      ('read', ReadingStatus.finished),
      ('favorites, read , currently-reading', ReadingStatus.finished),
      ('not-currently-reading', ReadingStatus.toRead),
      ('currently-reading-2026', ReadingStatus.toRead),
      ('not-read, read-2026, to-read', ReadingStatus.toRead),
      ('not-currently-reading, currently-reading-2026', ReadingStatus.toRead),
    ]) {
      final rss = '<rss><channel><item><user_shelves>$shelves</user_shelves>'
          '</item></channel></rss>';
      expect(parser.parse(rss, url).books.single.status, expected, reason: shelves);
      final query = Uri.parse(url).replace(queryParameters: {'shelf': shelves});
      expect(
        parser.parse('<rss><channel><item/></channel></rss>', query.toString())
            .books.single.status,
        expected,
        reason: 'shelf query: $shelves',
      );
    }
  });

  test('A valid finished date takes precedence; invalid timestamps do not imply completion', () {
    final feed = GoodreadsRssParser().parse('''<rss><channel>
      <item><user_shelves>not-currently-reading</user_shelves><user_read_at>2025-05-07T23:30:00-07:00</user_read_at></item>
      <item><user_shelves>currently-reading</user_shelves><user_read_at>2025-05-07junk</user_read_at><user_date_added>2025-05-01</user_date_added></item>
      <item><user_shelves>currently-reading-2026</user_shelves><user_read_at>2025-05-07T99:99:99+99:99</user_read_at></item>
    </channel></rss>''', url);
    expect(feed.books.map((book) => book.status), [
      ReadingStatus.finished,
      ReadingStatus.reading,
      ReadingStatus.toRead,
    ]);
    expect(feed.books.first.readAt, DateTime(2025, 5, 7));
    expect(feed.books[1].readAt, isNull);
    expect(feed.books[1].calendarDate, DateTime(2025, 5, 1));
    expect(feed.books.last.calendarDate, isNull);
  });

  test('Shelf query participates in status inference and read is matched as a comma token', () {
    const rss =
        '<rss><channel><item><user_shelves>to-read</user_shelves></item></channel></rss>';
    final parser = GoodreadsRssParser();
    expect(parser.parse(rss, url).books.single.status, ReadingStatus.toRead);
    expect(
      parser.parse(rss, '$url&shelf=read').books.single.status,
      ReadingStatus.finished,
    );
    expect(
      parser.parse(rss, '$url&shelf=currently-reading').books.single.status,
      ReadingStatus.reading,
    );
  });

  test('Malformed XML and missing channel fail with existing error copy', () {
    final parser = GoodreadsRssParser();
    expect(
      () => parser.parse('<rss>', url),
      throwsA(
        isA<FeedException>().having(
          (e) => e.message,
          'message',
          contains('couldn’t read this RSS feed'),
        ),
      ),
    );
    expect(
      () => parser.parse('<rss/>', url),
      throwsA(
        isA<FeedException>().having(
          (e) => e.message,
          'message',
          contains('did not return an RSS feed'),
        ),
      ),
    );
  });
}
