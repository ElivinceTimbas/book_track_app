import 'package:book_track_app/features/reading/data/cached_reading_repository.dart';
import 'package:book_track_app/features/reading/data/feed_json.dart';
import 'package:book_track_app/features/reading/data/goodreads_source.dart';
import 'package:book_track_app/features/reading/data/goodreads_url.dart';
import 'package:book_track_app/features/reading/data/reading_cache.dart';
import 'package:book_track_app/features/reading/data/rss_parser.dart';
import 'package:book_track_app/features/reading/domain/book.dart';
import 'package:book_track_app/features/reading/domain/feed_exception.dart';
import 'package:book_track_app/features/reading/presentation/book_labels.dart';
import 'package:book_track_app/features/reading/presentation/reading_controller.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const feedUrl = 'https://www.goodreads.com/review/list_rss/123?shelf=read';
const fixture = '''<?xml version="1.0"?>
<rss version="2.0"><channel><title>A reader’s shelf</title>
<item><book_id>42</book_id><title><![CDATA[A Book & Its World]]></title>
<author_name>A. Reader</author_name><num_pages>240</num_pages><user_rating>5</user_rating>
<user_read_at>Wed, 07 May 2025 00:00:00 -0700</user_read_at>
<user_date_added>Mon, 05 May 2025 12:00:00 -0700</user_date_added>
<book_image_url>http://example.com/cover.jpg</book_image_url></item>
<item><book_id>43</book_id><title>An Undated Read</title><author_name>Other Author</author_name>
<user_read_at></user_read_at><user_date_added>2025-05-03T23:30:00-07:00</user_date_added></item>
<item><book_id>44</book_id><title>No Date At All</title></item>
</channel></rss>''';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Goodreads dates preserve shelf day and distinguish added dates', () {
    final feed = GoodreadsRssParser().parse(fixture, feedUrl);
    expect(feed.name, 'A reader’s shelf');
    expect(feed.books, hasLength(3));
    final book = feed.books.first;
    expect(book.title, 'A Book & Its World');
    expect(book.readAt, DateTime(2025, 5, 7));
    expect(book.status, ReadingStatus.finished);
    expect(book.pages, 240);
    expect(book.rating, 5);
    expect(book.coverUrl, 'https://example.com/cover.jpg');
    expect(feed.books[1].calendarDate, DateTime(2025, 5, 3));
    expect(feed.books[1].eventLabel, 'Added to shelf');
    expect(feed.books[2].calendarDate, isNull);
    expect(bookFromJson(bookToJson(book)).readAt, book.readAt);
  });

  test('Invalid links and non-RSS responses have actionable errors', () {
    for (final link in [
      '',
      'https://example.com/feed',
      'https://goodreads.com/user/show/123',
      'https://goodreads.com.evil.com/review/list_rss/123',
    ]) {
      expect(() => normalizeGoodreadsUrl(link), throwsA(isA<FeedException>()));
    }
    expect(
      normalizeGoodreadsUrl(
        'http://goodreads.com/review/list_rss/123?shelf=read',
      ).scheme,
      'https',
    );
    expect(
      () => GoodreadsRssParser().parse('<html>Login</html>', feedUrl),
      throwsA(isA<FeedException>()),
    );
    expect(
      GoodreadsRssParser()
          .parse(
            '<rss><channel><title>Empty shelf</title></channel></rss>',
            feedUrl,
          )
          .books,
      isEmpty,
    );
  });

  test(
    'Feeds persist, deduplicate books, retain cache on failure, and disconnect',
    () async {
      var fail = false;
      final client = MockClient(
        (request) async => fail
            ? http.Response('Unavailable', 503)
            : http.Response(
                fixture,
                200,
                headers: {'content-type': 'application/rss+xml; charset=utf-8'},
              ),
      );
      addTearDown(client.close);
      final repository = CachedReadingRepository(
        source: GoodreadsSource(client: client, parser: GoodreadsRssParser()),
        cache: SharedPreferencesReadingCache(),
      );
      final store = ReadingController(repository: repository);
      addTearDown(store.dispose);
      await store.load();
      expect(store.books, isEmpty);
      await store.addFeed(feedUrl);
      expect(store.feeds, hasLength(1));
      expect(store.books, hasLength(3));
      await expectLater(store.addFeed(feedUrl), throwsA(isA<FeedException>()));
      await store.addFeed(
        'https://www.goodreads.com/review/list_rss/123?shelf=all',
      );
      expect(store.feeds, hasLength(2));
      expect(store.books, hasLength(3));

      final restored = ReadingController(repository: repository);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.feeds, hasLength(2));
      expect(restored.books.first.title, store.books.first.title);

      fail = true;
      await store.refresh();
      expect(store.syncing, isFalse);
      expect(store.error, contains('2 feeds couldn’t refresh'));
      expect(store.books, hasLength(3));
      await store.removeFeed(store.feeds.first);
      await store.removeFeed(store.feeds.first);
      expect(store.books, isEmpty);
      expect(store.feeds, isEmpty);
    },
  );
}
