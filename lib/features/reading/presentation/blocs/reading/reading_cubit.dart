import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/feed_exception.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/reading_feed.dart';
import '../../../domain/usecases/reading_library.dart';
import 'reading_state.dart';

/// Owns its library and exposes loading, activity and error state to the UI.
class ReadingCubit extends Cubit<ReadingState> {
  ReadingCubit({required this._library}) : super(ReadingState());

  final ReadingLibrary _library;
  bool _loading = true;
  bool _syncing = false;
  bool _disposed = false;
  int _mutations = 0;
  String? _error;

  List<ReadingFeed> get feeds => state.feeds;
  List<Book> get books => state.books;
  bool get loading => state.loading;
  bool get loadFailed => state.loadFailed;
  bool get busy => state.busy;
  bool get syncing => state.syncing;
  String? get error => state.error;

  void _publish() => emit(
    ReadingState(
      feeds: _library.feeds,
      loading: _loading,
      loaded: _library.loaded,
      mutations: _mutations,
      syncing: _syncing,
      error: _error,
    ),
  );

  Future<void> load() async {
    if (_disposed || _library.loaded) return;
    _loading = true;
    _error = null;
    _publish();
    try {
      await _library.load();
    } catch (_) {
      if (!_disposed) {
        _error =
            'Your saved shelves couldn’t be loaded. '
            'Retry before changing connections. '
            'Your saved data has not been overwritten.';
      }
    } finally {
      if (!_disposed) {
        _loading = false;
        _publish();
      }
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_disposed) return;
    _mutations++;
    _publish();
    try {
      await action();
    } finally {
      _mutations--;
      if (!_disposed) _publish();
    }
  }

  Future<void> addFeed(String url) => _mutate(() async {
    try {
      await _library.addFeed(url);
      if (!_disposed) _error = null;
    } catch (exception) {
      if (!_disposed && _library.loaded) {
        _error = exception is FeedException
            ? exception.message
            : 'This shelf couldn’t be saved. Please try again.';
      }
      rethrow;
    }
  });

  Future<void> removeFeed(ReadingFeed feed) => _mutate(() async {
    try {
      await _library.removeFeed(feed);
      if (!_disposed) _error = null;
    } catch (_) {
      if (!_disposed && _library.loaded) {
        _error = 'The shelf couldn’t be removed. Please try again.';
      }
      rethrow;
    }
  });

  Future<void> refresh() async {
    if (_disposed || _syncing || (_library.loaded && feeds.isEmpty)) return;
    _syncing = true;
    try {
      await _mutate(() async {
        if (_library.loaded) _error = null;
        try {
          final failed = await _library.refresh();
          if (!_disposed) {
            _error = failed == 0
                ? null
                : '$failed ${failed == 1 ? 'feed couldn’t' : 'feeds couldn’t'} '
                      'refresh. Previously saved books are still available.';
          }
        } catch (_) {
          if (!_disposed && _library.loaded) {
            _error = 'The refreshed feeds couldn’t be saved. Please try again.';
          }
        }
      });
    } finally {
      _syncing = false;
      if (!_disposed) _publish();
    }
  }

  @override
  Future<void> close() {
    _disposed = true;
    _library.dispose();
    return super.close();
  }
}
