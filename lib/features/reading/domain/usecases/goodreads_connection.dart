import '../../../../core/errors/feed_exception.dart';

String _userId(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+$').hasMatch(value) || BigInt.parse(value) <= BigInt.zero) {
    throw const FeedException('Enter a positive numeric Goodreads user ID.');
  }
  return BigInt.parse(value).toString();
}

Uri goodreadsShelfUrl({required String userId, required String shelf}) {
  final id = _userId(userId);
  final slug = shelf.trim();
  if (slug.isEmpty) {
    throw const FeedException('Enter a custom shelf slug.');
  }
  return Uri.https('www.goodreads.com', '/review/list_rss/$id', {'shelf': slug});
}

Uri normalizeGoodreadsUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      !['goodreads.com', 'www.goodreads.com'].contains(uri.host.toLowerCase()) ||
      !RegExp(r'^/review/list_rss/\d+/?$').hasMatch(uri.path) ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443 && uri.port != 80)) {
    throw const FeedException(
      'Paste a Goodreads shelf RSS link, like '
      'https://www.goodreads.com/review/list_rss/123456?shelf=read',
    );
  }
  final id = _userId(uri.pathSegments.where((s) => s.isNotEmpty).last);
  return uri.replace(
    scheme: 'https',
    host: 'www.goodreads.com',
    port: 443,
    path: '/review/list_rss/$id',
    fragment: '',
  );
}

/// Request parameters stay on the URL; identity and display never expose keys.
({String userId, String shelf})? goodreadsConnection(String url) {
  try {
    final uri = normalizeGoodreadsUrl(url);
    return (
      userId: uri.pathSegments.last,
      shelf: uri.queryParameters['shelf'] ?? 'all',
    );
  } on FeedException {
    return null;
  }
}

bool sameGoodreadsShelf(String first, String second) {
  final connection = goodreadsConnection(first);
  return connection == null
      ? first == second
      : connection == goodreadsConnection(second);
}

String goodreadsConnectionLabel(String url) {
  final connection = goodreadsConnection(url);
  return connection == null
      ? 'Saved Goodreads RSS connection'
      : 'User ${connection.userId} · Shelf: ${connection.shelf}';
}
