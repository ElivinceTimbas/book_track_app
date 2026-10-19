import 'package:book_track_app/features/reading/domain/feed_exception.dart';
import 'package:book_track_app/features/reading/domain/goodreads_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('User ID and standard shelves build HTTPS RSS URLs', () {
    for (final shelf in ['read', 'currently-reading', 'to-read']) {
      final uri = goodreadsShelfUrl(userId: ' 00123 ', shelf: shelf);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.goodreads.com');
      expect(uri.path, '/review/list_rss/123');
      expect(uri.queryParameters, {'shelf': shelf});
    }
  });

  test('Missing, zero and malformed IDs are rejected in both paths', () {
    for (final id in ['', ' ', '0', '000', '-1', '+1', '1.2', '1e3', '12a', '1/2', '1 2', '１２']) {
      expect(() => goodreadsShelfUrl(userId: id, shelf: 'read'), throwsA(isA<FeedException>()), reason: id);
      expect(() => normalizeGoodreadsUrl('https://goodreads.com/review/list_rss/$id?shelf=read'), throwsA(isA<FeedException>()), reason: id);
    }
  });

  test('Custom shelf is required and query values cannot inject parameters', () {
    for (final shelf in ['', '   ']) {
      expect(() => goodreadsShelfUrl(userId: '123', shelf: shelf), throwsA(isA<FeedException>()));
    }
    final uri = goodreadsShelfUrl(userId: '123', shelf: ' café & more/#?key=secret ');
    expect(uri.queryParameters, {'shelf': 'café & more/#?key=secret'});
    expect(uri.fragment, isEmpty);
    expect(uri.queryParameters.containsKey('key'), isFalse);
  });

  test('Equivalent shelf identity ignores scheme, slash, query order and keys without stripping request params', () {
    const original = 'http://goodreads.com/review/list_rss/00123/?key=a%2Bb&x=1&x=2&shelf=read#fragment';
    final uri = normalizeGoodreadsUrl(original);
    expect(uri.query, 'key=a%2Bb&x=1&x=2&shelf=read');
    expect(uri.queryParametersAll['x'], ['1', '2']);
    expect(sameGoodreadsShelf(original, goodreadsShelfUrl(userId: '123', shelf: 'read').toString()), isTrue);
    expect(sameGoodreadsShelf(original, goodreadsShelfUrl(userId: '123', shelf: 'to-read').toString()), isFalse);
    expect(goodreadsConnectionLabel(original), 'User 123 · Shelf: read');
    expect(goodreadsConnectionLabel('invalid?key=private'), isNot(contains('private')));
  });
}
