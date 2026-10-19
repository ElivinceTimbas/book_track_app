import 'dart:convert';

import 'package:book_track_app/features/reading/data/feed_json.dart';
import 'package:book_track_app/features/reading/data/reading_cache.dart';
import 'package:book_track_app/features/reading/domain/book.dart';
import 'package:book_track_app/features/reading/domain/feed_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/reading_fakes.dart';

// Literal pre-refactor v1 payload, deliberately not produced by the new mapper.
const legacyJson = '''[
  {
    "url":"https://www.goodreads.com/review/list_rss/123?shelf=all&key=abc",
    "name":"Reader’s shelf",
    "books":[
      {"id":"42","title":"A Book","author":"A. Reader","coverUrl":"https://example.com/cover.jpg","status":"finished","pages":240,"rating":5,"readAt":"2025-05-07T00:00:00.000","startedAt":"2025-05-01T00:00:00.000","addedAt":"2025-04-30T23:30:00.000Z"},
      {"id":"43","title":"Reading","author":"Other","coverUrl":"","status":"reading","pages":0,"rating":0,"readAt":null,"startedAt":"2025-05-08T00:00:00.000","addedAt":null},
      {"id":"44","title":"Undated","author":"Other","coverUrl":"","status":"toRead","pages":0,"rating":0,"readAt":null,"startedAt":null,"addedAt":null}
    ],
    "syncedAt":"2025-05-09T12:34:56.000Z"
  }
]''';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Literal legacy cache decodes and re-encodes with exact v1 schema and dates', () async {
    SharedPreferences.setMockInitialValues({
      'folio.feeds.v1': legacyJson,
      'unrelated': 'keep',
    });
    final cache = SharedPreferencesReadingCache();
    final feeds = await cache.load();
    final feed = feeds.single;
    expect(feed.name, 'Reader’s shelf');
    expect(feed.syncedAt, DateTime.utc(2025, 5, 9, 12, 34, 56));
    expect(feed.books.map((book) => book.status), ReadingStatus.values);
    expect(feed.books.first.calendarDate, DateTime(2025, 5, 7));
    expect(feed.books.first.addedAt!.isUtc, isTrue);
    expect(feed.books.last.calendarDate, isNull);
    expect(feedToJson(feed), (jsonDecode(legacyJson) as List).single);
    expect(() => feeds.clear(), throwsUnsupportedError);
    await cache.save(feeds);
    final preferences = await SharedPreferences.getInstance();
    expect(
      jsonDecode(preferences.getString('folio.feeds.v1')!),
      jsonDecode(legacyJson),
    );
    expect(preferences.getString('unrelated'), 'keep');
  });

  test('Missing optional book fields retain legacy defaults', () {
    final book = bookFromJson({
      'id': 'id',
      'title': 'Title',
      'author': 'Author',
      'status': 'toRead',
    });
    expect(book.coverUrl, '');
    expect(book.pages, 0);
    expect(book.rating, 0);
    expect(book.calendarDate, isNull);
  });

  test('Missing cache loads empty; saving empty writes a v1 list', () async {
    final cache = SharedPreferencesReadingCache();
    expect(await cache.load(), isEmpty);
    await cache.save([]);
    expect(
      (await SharedPreferences.getInstance()).getString('folio.feeds.v1'),
      '[]',
    );
  });

  test(
    'Corrupt cache propagates rather than silently overwriting stored data',
    () async {
      SharedPreferences.setMockInitialValues({'folio.feeds.v1': 'not JSON'});
      await expectLater(
        SharedPreferencesReadingCache().load(),
        throwsFormatException,
      );
      expect(
        (await SharedPreferences.getInstance()).getString('folio.feeds.v1'),
        'not JSON',
      );
    },
  );

  test(
    'False preference write result becomes an actionable persistence failure',
    () async {
      final preferences = RejectingPreferences();
      final cache = SharedPreferencesReadingCache(
        preferences: () async => preferences,
      );
      await expectLater(
        cache.save([sampleFeed()]),
        throwsA(
          isA<FeedException>().having(
            (e) => e.message,
            'message',
            contains('couldn’t be saved'),
          ),
        ),
      );
      expect(preferences.key, 'folio.feeds.v1');
      expect(jsonDecode(preferences.value!), [feedToJson(sampleFeed())]);
    },
  );

  test(
    'Preference initialization failure propagates for both reads and writes',
    () async {
      final cache = SharedPreferencesReadingCache(
        preferences: () async => throw StateError('unavailable'),
      );
      await expectLater(cache.load(), throwsStateError);
      await expectLater(cache.save([]), throwsStateError);
    },
  );
}

class RejectingPreferences implements SharedPreferences {
  String? key;
  String? value;

  @override
  Future<bool> setString(String key, String value) async {
    this.key = key;
    this.value = value;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
