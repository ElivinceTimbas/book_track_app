import 'package:book_track_app/features/reading/data/datasources/goodreads_source.dart';
import 'package:book_track_app/features/reading/data/datasources/reading_cache.dart';
import 'package:book_track_app/features/reading/data/repositories/cached_reading_repository.dart';
import 'package:book_track_app/features/reading/domain/entities/reading_feed.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_fakes.dart';

void main() {
  test(
    'Repository keeps cache load/save separate from source normalize/fetch',
    () async {
      final cache = FakeCache();
      final source = FakeSource();
      final repository = CachedReadingRepository(source: source, cache: cache);
      final cached = await repository.load();
      expect(cached.single.name, 'Cached');
      expect(source.calls, isEmpty);
      expect(repository.normalizeUrl('input'), 'normalized');
      final fresh = await repository.fetch('normalized');
      expect(fresh.name, 'Fresh');
      expect(source.calls, ['normalize:input', 'fetch:normalized']);
      expect(
        cache.saved,
        isNull,
      ); // Fetch never implicitly persists or publishes.
      await repository.save([fresh]);
      expect(cache.saved, [same(fresh)]);
      expect(source.calls, hasLength(2));
    },
  );

  test(
    'Repository propagates cache failures, without a network fallback',
    () async {
      final source = FakeSource();
      final repository = CachedReadingRepository(
        source: source,
        cache: FakeCache()..fail = true,
      );
      await expectLater(repository.load(), throwsStateError);
      await expectLater(repository.save([]), throwsStateError);
      expect(source.calls, isEmpty);
    },
  );
}

class FakeCache implements ReadingCache {
  bool fail = false;
  List<ReadingFeed>? saved;

  @override
  Future<List<ReadingFeed>> load() async {
    if (fail) throw StateError('read');
    return [sampleFeed(name: 'Cached')];
  }

  @override
  Future<void> save(List<ReadingFeed> feeds) async {
    if (fail) throw StateError('write');
    saved = feeds;
  }
}

class FakeSource implements ReadingFeedSource {
  final calls = <String>[];

  @override
  String normalizeUrl(String input) {
    calls.add('normalize:$input');
    return 'normalized';
  }

  @override
  Future<ReadingFeed> fetch(String url) async {
    calls.add('fetch:$url');
    return sampleFeed(name: 'Fresh');
  }
}
