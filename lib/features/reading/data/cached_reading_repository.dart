import '../domain/reading_feed.dart';
import '../domain/reading_repository.dart';
import 'goodreads_source.dart';
import 'reading_cache.dart';

class CachedReadingRepository implements ReadingRepository {
  CachedReadingRepository({required this._source, required this._cache});

  final ReadingFeedSource _source;
  final ReadingCache _cache;

  @override
  Future<List<ReadingFeed>> load() => _cache.load();

  @override
  Future<void> save(List<ReadingFeed> feeds) => _cache.save(feeds);

  @override
  String normalizeUrl(String input) => _source.normalizeUrl(input);

  @override
  Future<ReadingFeed> fetch(String url) => _source.fetch(url);
}
