import 'dart:async';

import 'package:book_track_app/core/errors/feed_exception.dart';
import 'package:book_track_app/features/reading/data/datasources/goodreads_source.dart';
import 'package:book_track_app/features/reading/data/models/rss_parser.dart';
import 'package:book_track_app/features/reading/domain/usecases/goodreads_connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const url = 'https://www.goodreads.com/review/list_rss/123?shelf=read';
const emptyRss = '<rss><channel><title>Empty</title></channel></rss>';

void main() {
  test('URL canonicalization preserves path and query, strips fragment, forces HTTPS host/port', () {
    final uri = normalizeGoodreadsUrl(
      ' http://goodreads.com:80/review/list_rss/123/?shelf=read&key=a%2Bb&x=1&x=2#ignored ',
    );
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.goodreads.com');
    expect(uri.port, 443);
    expect(uri.path, '/review/list_rss/123');
    expect(uri.query, 'shelf=read&key=a%2Bb&x=1&x=2');
    expect(uri.fragment, '');
    expect(normalizeGoodreadsUrl(uri.toString()), uri);
  });

  test('URL restrictions reject credentials, foreign hosts/paths, schemes and nonstandard ports', () {
    for (final input in [
      'ftp://www.goodreads.com/review/list_rss/123',
      'https://user:pass@goodreads.com/review/list_rss/123',
      'https://goodreads.com:444/review/list_rss/123',
      'https://goodreads.com.evil.com/review/list_rss/123',
      'https://evil.goodreads.com/review/list_rss/123',
      'https://goodreads.com/review/list_rss/not-a-number',
      'https://goodreads.com/review/list_rss/123/extra',
    ]) {
      expect(
        () => normalizeGoodreadsUrl(input),
        throwsA(isA<FeedException>()),
        reason: input,
      );
    }
  });

  test('Source sends canonical request and original Accept header, then invokes independent parser', () async {
    final now = DateTime(2025, 5, 7, 12);
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(emptyRss, 200);
    });
    addTearDown(client.close);
    final source = GoodreadsSource(
      client: client,
      parser: GoodreadsRssParser(now: () => now),
    );
    final feed = await source.fetch(
      'http://goodreads.com/review/list_rss/123?shelf=read#fragment',
    );
    // Legacy Uri.replace(fragment: '') clears the value but keeps an empty #.
    expect(captured!.url.toString(), '$url#');
    expect(captured!.method, 'GET');
    expect(
      captured!.headers.entries
          .singleWhere((entry) => entry.key.toLowerCase() == 'accept')
          .value,
      'application/rss+xml, application/xml',
    );
    expect(feed.url, '$url#');
    expect(feed.name, 'Empty');
    expect(feed.syncedAt, now);
  });

  for (final code in [401, 403, 503]) {
    test('HTTP $code preserves actionable status error', () async {
      final client = MockClient(
        (_) async => http.Response('unavailable', code),
      );
      addTearDown(client.close);
      final source = GoodreadsSource(
        client: client,
        parser: GoodreadsRssParser(),
      );
      await expectLater(
        source.fetch(url),
        throwsA(
          isA<FeedException>().having(
            (error) => error.message,
            'message',
            code == 503
                ? contains('Goodreads returned 503')
                : contains('Make your Goodreads profile and shelf public'),
          ),
        ),
      );
    });
  }

  test(
    'Transport failures are translated; parser errors are not masked',
    () async {
      final offline = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      final html = MockClient(
        (_) async => http.Response('<html>Login</html>', 200),
      );
      addTearDown(offline.close);
      addTearDown(html.close);
      await expectLater(
        GoodreadsSource(
          client: offline,
          parser: GoodreadsRssParser(),
        ).fetch(url),
        throwsA(
          isA<FeedException>().having(
            (e) => e.message,
            'message',
            contains('couldn’t reach this feed'),
          ),
        ),
      );
      await expectLater(
        GoodreadsSource(client: html, parser: GoodreadsRssParser()).fetch(url),
        throwsA(
          isA<FeedException>().having(
            (e) => e.message,
            'message',
            contains('did not return an RSS feed'),
          ),
        ),
      );
    },
  );

  testWidgets(
    'Source timeout remains exactly 25 seconds without waiting in real time',
    (tester) async {
      final pending = Completer<http.Response>();
      final client = MockClient((_) => pending.future);
      addTearDown(client.close);
      Object? failure;
      final fetching =
          GoodreadsSource(client: client, parser: GoodreadsRssParser())
              .fetch(url)
              .then<void>(
                (_) {},
                onError: (Object error) {
                  failure = error;
                },
              );
      await tester.pump();
      await tester.pump(const Duration(seconds: 24));
      expect(failure, isNull);
      await tester.pump(const Duration(seconds: 1));
      await fetching;
      expect(
        failure,
        isA<FeedException>().having(
          (e) => e.message,
          'message',
          contains('couldn’t reach this feed'),
        ),
      );
      pending.complete(http.Response(emptyRss, 200));
      await tester.pump();
    },
  );
}
