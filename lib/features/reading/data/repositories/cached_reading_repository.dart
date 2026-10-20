import '../../domain/entities/reading_feed.dart';
import '../../domain/repositories/reading_repository.dart';
import '../datasources/goodreads_source.dart';
import '../datasources/reading_cache.dart';

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
