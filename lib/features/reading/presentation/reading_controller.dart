import 'package:flutter/foundation.dart';

import '../domain/book.dart';
import '../domain/feed_exception.dart';
import '../domain/goodreads_connection.dart';
import '../domain/reading_feed.dart';
import '../domain/reading_repository.dart';
import '../domain/reading_rules.dart';

/// Borrows the repository. Mutations publish only after successful persistence.
class ReadingController extends ChangeNotifier {
  ReadingController({required this._repository});

  final ReadingRepository _repository;
  List<ReadingFeed> _feeds = const [];
  Future<void> _tail = Future<void>.value();
  bool _loading = true;
  bool _loaded = false;
  bool _syncing = false;
  bool _disposed = false;
  int _mutations = 0;
  String? _error;

  List<ReadingFeed> get feeds => _feeds;
  bool get loading => _loading;
  bool get loadFailed => !_loading && !_loaded;
  bool get busy => _mutations > 0;
  bool get syncing => _syncing;
  String? get error => _error;
  List<Book> get books => mergeBooks(_feeds);

  Future<void> _serialize(Future<void> Function() action) {
    final next = _tail.then((_) async {
      if (!_disposed) await action();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> load() => _serialize(() async {
    if (_loaded) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _repository.load();
      if (_disposed) return;
      _feeds = List.unmodifiable(saved);
      _loaded = true;
    } catch (_) {
      if (_disposed) return;
      _error = 'Your saved shelves couldn’t be loaded. '
          'Retry before changing connections. '
          'Your saved data has not been overwritten.';
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  });

  Future<void> _mutate(Future<void> Function() action) {
    if (_disposed) return Future<void>.value();
    _mutations++;
    notifyListeners();
    return _serialize(() async {
      if (!_loaded) {
        throw const FeedException(
          'Retry loading your saved shelves before making changes.',
        );
      }
      await action();
    }).whenComplete(() {
      _mutations--;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _save(List<ReadingFeed> updated) async {
    if (_disposed) return;
    final snapshot = List<ReadingFeed>.unmodifiable(updated);
    await _repository.save(snapshot);
    if (!_disposed) _feeds = snapshot;
  }

  Future<void> addFeed(String url) => _mutate(() async {
    try {
      final normalized = _repository.normalizeUrl(url);
      if (_feeds.any((feed) => sameGoodreadsShelf(feed.url, normalized))) {
        throw const FeedException(
          'This shelf is already connected. Use Refresh to sync it again.',
        );
      }
      final feed = await _repository.fetch(normalized);
      if (_disposed) return;
      await _save([..._feeds, feed]);
      if (!_disposed) _error = null;
    } catch (exception) {
      if (!_disposed) {
        _error = exception is FeedException
            ? exception.message
            : 'This shelf couldn’t be saved. Please try again.';
      }
      rethrow;
    }
  });

  Future<void> removeFeed(ReadingFeed feed) => _mutate(() async {
    try {
      await _save(
        _feeds.where((item) => !sameGoodreadsShelf(item.url, feed.url)).toList(),
      );
      if (!_disposed) _error = null;
    } catch (_) {
      if (!_disposed) {
        _error = 'The shelf couldn’t be removed. Please try again.';
      }
      rethrow;
    }
  });

  Future<void> refresh() async {
    if (_disposed || _syncing || (_loaded && _feeds.isEmpty)) return;
    _syncing = true;
    try {
      await _mutate(() async {
        _error = null;
        final updated = <ReadingFeed>[];
        var failed = 0;
        for (final feed in _feeds) {
          if (_disposed) return;
          try {
            updated.add(await _repository.fetch(feed.url));
          } catch (_) {
            updated.add(feed);
            failed++;
          }
        }
        if (_disposed) return;
        try {
          await _save(updated);
          if (!_disposed && failed > 0) {
            _error = '$failed ${failed == 1 ? 'feed couldn’t' : 'feeds couldn’t'} '
                'refresh. Previously saved books are still available.';
          }
        } catch (_) {
          if (!_disposed) {
            _error = 'The refreshed feeds couldn’t be saved. Please try again.';
          }
        }
      });
    } on FeedException {
      // The cache-load error and its retry action remain visible.
    } finally {
      _syncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
