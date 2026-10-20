import 'package:http/http.dart' as http;

import '../../../../core/errors/feed_exception.dart';
import '../../domain/entities/reading_feed.dart';
import '../../domain/usecases/goodreads_connection.dart';
import '../models/rss_parser.dart';

abstract interface class ReadingFeedSource {
  String normalizeUrl(String input);
  Future<ReadingFeed> fetch(String url);
}

/// Borrows its HTTP client. The creator owns and closes the client.
class GoodreadsSource implements ReadingFeedSource {
  GoodreadsSource({required this._client, required this._parser});

  final http.Client _client;
  final GoodreadsRssParser _parser;

  @override
  String normalizeUrl(String input) => normalizeGoodreadsUrl(input).toString();

  @override
  Future<ReadingFeed> fetch(String input) async {
    final uri = normalizeGoodreadsUrl(input);
    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/rss+xml, application/xml'})
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw FeedException(
          response.statusCode == 403 || response.statusCode == 401
              ? 'This shelf is not accessible. Make your Goodreads profile and shelf public, then try again.'
              : 'Goodreads returned ${response.statusCode}. Check the RSS link and try again.',
        );
      }
      return _parser.parse(response.body, uri.toString());
    } on FeedException {
      rethrow;
    } catch (_) {
      throw const FeedException(
        'We couldn’t reach this feed. Check your connection and make sure the RSS link is public.',
      );
    }
  }
}
