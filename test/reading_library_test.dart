import 'dart:async';

import 'package:book_track_app/core/errors/feed_exception.dart';
import 'package:book_track_app/features/reading/domain/entities/reading_feed.dart';
import 'package:book_track_app/features/reading/domain/usecases/reading_library.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_fakes.dart';

void main() {
  late FakeReadingRepository repository;
  late ReadingLibrary library;

  setUp(() {
    repository = FakeReadingRepository();
    library = ReadingLibrary(repository: repository);
  });
  tearDown(() => library.dispose());

  test('failed load blocks writes until a successful retry', () async {
    final original = sampleFeed();
    repository.stored = [original];
    repository.onLoad = () async => throw StateError('unavailable');
    await expectLater(library.load(), throwsStateError);
    await expectLater(library.addFeed('feed-b'), throwsA(isA<FeedException>()));
    await expectLater(
      library.removeFeed(original),
      throwsA(isA<FeedException>()),
    );
    await expectLater(library.refresh(), throwsA(isA<FeedException>()));
    expect(repository.saves, isEmpty);
    expect(repository.fetched, isEmpty);
    expect(library.loaded, isFalse);
    repository.onLoad = null;
    await library.load();
    expect(library.loaded, isTrue);
    expect(library.feeds, [same(original)]);
  });

  test(
    'queued adds wait for load, deduplicate and publish only after saving',
    () async {
      final loading = Completer<List<ReadingFeed>>();
      final saving = Completer<void>();
      repository.onLoad = () => loading.future;
      repository.onSave = (_) => saving.future;
      final load = library.load();
      final first = library.addFeed(' feed-a ');
      final duplicate = expectLater(
        library.addFeed('feed-a'),
        throwsA(isA<FeedException>()),
      );
      loading.complete([]);
      await load;
      await Future<void>.delayed(Duration.zero);
      expect(library.feeds, isEmpty);
      saving.complete();
      await first;
      await duplicate;
      expect(repository.fetched, ['feed-a']);
      expect(library.feeds.single.url, 'feed-a');
      expect(() => library.feeds.clear(), throwsUnsupportedError);
    },
  );

  test(
    'refresh retains failed shelves and failed persistence retains all state',
    () async {
      final first = sampleFeed();
      final second = sampleFeed(url: 'feed-b');
      final fresh = sampleFeed(name: 'Fresh');
      repository.stored = [first, second];
      repository.onFetch = (url) async {
        if (url == 'feed-b') throw const FeedException('offline');
        return fresh;
      };
      await library.load();
      repository.onSave = (_) async => throw StateError('disk full');
      await expectLater(library.refresh(), throwsStateError);
      expect(library.feeds, [same(first), same(second)]);
      repository.onSave = null;
      expect(await library.refresh(), 1);
      expect(library.feeds, [same(fresh), same(second)]);
    },
  );

  test('disposal drops an active fetch and queued mutations', () async {
    final fetching = Completer<ReadingFeed>();
    repository.onFetch = (_) => fetching.future;
    await library.load();
    final first = library.addFeed('feed-a');
    final second = library.addFeed('feed-b');
    await Future<void>.delayed(Duration.zero);
    library.dispose();
    fetching.complete(sampleFeed());
    await Future.wait([first, second]);
    expect(repository.fetched, ['feed-a']);
    expect(repository.saves, isEmpty);
    expect(library.feeds, isEmpty);
  });
}
