import '../../../../core/errors/feed_exception.dart';
import '../entities/book.dart';
import '../entities/reading_feed.dart';
import '../repositories/reading_repository.dart';
import 'goodreads_connection.dart';
import 'reading_rules.dart';

/// Serializes shelf operations and publishes only successfully saved snapshots.
class ReadingLibrary {
  ReadingLibrary({required this._repository});

  final ReadingRepository _repository;
  List<ReadingFeed> _feeds = const [];
  Future<void> _tail = Future<void>.value();
  bool _loaded = false;
  bool _disposed = false;

  List<ReadingFeed> get feeds => _feeds;
  List<Book> get books => mergeBooks(_feeds);
  bool get loaded => _loaded;

  Future<void> _serialize(Future<void> Function() action) {
    final next = _tail.then((_) async {
      if (!_disposed) await action();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> load() => _serialize(() async {
    if (_loaded) return;
    final saved = await _repository.load();
    if (_disposed) return;
    _feeds = List.unmodifiable(saved);
    _loaded = true;
  });

  Future<void> _mutate(Future<void> Function() action) => _serialize(() async {
    if (!_loaded) {
      throw const FeedException(
        'Retry loading your saved shelves before making changes.',
      );
    }
    await action();
  });

  Future<void> _save(List<ReadingFeed> updated) async {
    if (_disposed) return;
    final snapshot = List<ReadingFeed>.unmodifiable(updated);
    await _repository.save(snapshot);
    if (!_disposed) _feeds = snapshot;
  }

  Future<void> addFeed(String url) => _mutate(() async {
    final normalized = _repository.normalizeUrl(url);
    if (_feeds.any((feed) => sameGoodreadsShelf(feed.url, normalized))) {
      throw const FeedException(
        'This shelf is already connected. Use Refresh to sync it again.',
      );
    }
    final feed = await _repository.fetch(normalized);
    if (!_disposed) await _save([..._feeds, feed]);
  });

  Future<void> removeFeed(ReadingFeed feed) => _mutate(
    () => _save(
      _feeds.where((item) => !sameGoodreadsShelf(item.url, feed.url)).toList(),
    ),
  );

  /// Returns the number of shelves whose cached snapshot had to be retained.
  Future<int> refresh() async {
    var failed = 0;
    await _mutate(() async {
      if (_feeds.isEmpty) return;
      final updated = <ReadingFeed>[];
      for (final feed in _feeds) {
        if (_disposed) return;
        try {
          updated.add(await _repository.fetch(feed.url));
        } catch (_) {
          updated.add(feed);
          failed++;
        }
      }
      await _save(updated);
    });
    return failed;
  }

  /// Drops queued work and late results; already issued writes may finish.
  void dispose() => _disposed = true;
}
