import 'dart:async';

import 'package:book_track_app/features/reading/domain/feed_exception.dart';
import 'package:book_track_app/features/reading/domain/reading_feed.dart';
import 'package:book_track_app/features/reading/presentation/reading_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_fakes.dart';

void main() {
  late FakeReadingRepository repository;
  late ReadingController controller;

  setUp(() {
    repository = FakeReadingRepository();
    controller = ReadingController(
      repository: repository,
    );
  });
  tearDown(() => controller.dispose());

  test('Empty cache and empty connected shelf contain no fabricated books', () async {
    expect(controller.loading, isTrue);
    await controller.load();
    expect(controller.loading, isFalse);
    expect(controller.feeds, isEmpty);
    expect(controller.books, isEmpty);
    expect(() => controller.books.clear(), throwsUnsupportedError);
    await controller.addFeed('feed-a');
    expect(controller.feeds, hasLength(1));
    expect(controller.books, isEmpty);
  });

  test('Load failure ends loading with actionable error and no fabricated books', () async {
    repository.onLoad = () async => throw StateError('corrupt cache');
    await controller.load();
    expect(controller.loading, isFalse);
    expect(
      controller.error,
      contains('Retry before changing connections'),
    );
    expect(controller.books, isEmpty);
    expect(controller.loadFailed, isTrue);
  });

  test(
    'Loaded feeds and saved snapshots cannot be mutated externally',
    () async {
      final feed = sampleFeed(books: [sampleBook()]);
      repository.stored = [feed];
      await controller.load();
      repository.stored.clear();
      expect(controller.feeds, [same(feed)]);
      expect(() => controller.feeds.clear(), throwsUnsupportedError);
      await controller.addFeed('feed-b');
      expect(() => repository.saves.single.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Add normalizes before duplicate detection and does not fetch duplicates',
    () async {
      repository.stored = [sampleFeed()];
      await controller.load();
      await expectLater(
        controller.addFeed(' feed-a '),
        throwsA(isA<FeedException>()),
      );
      expect(repository.normalized, [' feed-a ']);
      expect(repository.fetched, isEmpty);
      expect(repository.saves, isEmpty);
    },
  );

  test(
    'Add waits for persistence before publishing and clears previous error',
    () async {
      await controller.load();
      final save = Completer<void>();
      repository.onSave = (_) => save.future;
      var notifications = 0;
      controller.addListener(() => notifications++);
      final adding = controller.addFeed(' feed-a ');
      await Future<void>.delayed(Duration.zero);
      expect(repository.fetched, ['feed-a']);
      expect(repository.saves, hasLength(1));
      expect(controller.feeds, isEmpty);
      expect(notifications, 1);
      save.complete();
      await adding;
      expect(controller.feeds.single.url, 'feed-a');
      expect(controller.error, isNull);
      expect(notifications, 2);
    },
  );

  test('Failed add fetch or save never publishes an unsaved feed', () async {
    await controller.load();
    repository.onFetch = (_) async => throw const FeedException('offline');
    await expectLater(
      controller.addFeed('feed-a'),
      throwsA(isA<FeedException>()),
    );
    expect(repository.saves, isEmpty);
    repository.onFetch = null;
    repository.onSave = (_) async => throw StateError('disk full');
    await expectLater(controller.addFeed('feed-a'), throwsStateError);
    expect(controller.feeds, isEmpty);
    expect(controller.books, isEmpty);
  });

  test(
    'Failed removal retains books; successful last removal leaves a genuinely empty library',
    () async {
      final feed = sampleFeed(books: [sampleBook()]);
      repository.stored = [feed];
      await controller.load();
      repository.onSave = (_) async => throw StateError('disk full');
      await expectLater(controller.removeFeed(feed), throwsStateError);
      expect(controller.feeds.single, same(feed));
      expect(controller.books, hasLength(1));
      repository.onSave = null;
      await controller.removeFeed(feed);
      expect(controller.books, isEmpty);
      expect(repository.stored, isEmpty);
    },
  );

  test('Refresh is sequential, ignores reentry, and saves successes plus cached failures in order', () async {
    final a = sampleFeed();
    final b = sampleFeed(
      url: 'feed-b',
      books: [sampleBook(id: 'cached')],
    );
    final updated = sampleFeed(
      name: 'Updated',
      books: [sampleBook(id: 'fresh')],
    );
    repository.stored = [a, b];
    await controller.load();
    final first = Completer<ReadingFeed>();
    repository.onFetch = (url) => url == 'feed-a'
        ? first.future
        : Future.error(const FeedException('offline'));
    final refreshing = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(controller.syncing, isTrue);
    expect(repository.fetched, ['feed-a']);
    await controller.refresh();
    expect(repository.fetched, ['feed-a']);
    expect(repository.saves, isEmpty);
    first.complete(updated);
    await refreshing;
    expect(repository.fetched, ['feed-a', 'feed-b']);
    expect(repository.saves.single, [same(updated), same(b)]);
    expect(controller.feeds, [same(updated), same(b)]);
    expect(
      controller.books.map((book) => book.id),
      containsAll(['fresh', 'cached']),
    );
    expect(controller.syncing, isFalse);
    expect(
      controller.error,
      '1 feed couldn’t refresh. Previously saved books are still available.',
    );
  });

  test(
    'Refresh persistence failure retains all old feeds and ends syncing',
    () async {
      final original = sampleFeed();
      repository.stored = [original];
      await controller.load();
      repository.onFetch = (_) async => sampleFeed(name: 'New');
      repository.onSave = (_) async => throw StateError('disk full');
      await controller.refresh();
      expect(controller.feeds, [same(original)]);
      expect(controller.syncing, isFalse);
      expect(
        controller.error,
        'The refreshed feeds couldn’t be saved. Please try again.',
      );
    },
  );

  test('Refreshing an empty library is a no-op', () async {
    await controller.load();
    await controller.refresh();
    expect(repository.fetched, isEmpty);
    expect(repository.saves, isEmpty);
    expect(controller.syncing, isFalse);
  });

  test('Cache failure guards every write until retry restores unread shelves', () async {
    final original = sampleFeed(books: [sampleBook(id: 'saved')]);
    repository.stored = [original];
    repository.onLoad = () async => throw StateError('temporarily unavailable');
    await controller.load();
    await expectLater(controller.addFeed('feed-b'), throwsA(isA<FeedException>()));
    await expectLater(controller.removeFeed(original), throwsA(isA<FeedException>()));
    await controller.refresh();
    expect(repository.saves, isEmpty);
    expect(repository.fetched, isEmpty);
    expect(repository.stored, [same(original)]);
    expect(controller.loadFailed, isTrue);
    repository.onLoad = null;
    await controller.load();
    expect(controller.loadFailed, isFalse);
    expect(controller.error, isNull);
    expect(controller.books.single.id, 'saved');
    await controller.addFeed('feed-b');
    expect(controller.feeds.map((feed) => feed.url), ['feed-a', 'feed-b']);
  });

  test('Add during initial load waits for cache before duplicate detection', () async {
    final pending = Completer<List<ReadingFeed>>();
    repository.onLoad = () => pending.future;
    final loading = controller.load();
    final adding = controller.addFeed('feed-a');
    final assertion = expectLater(adding, throwsA(isA<FeedException>()));
    pending.complete([sampleFeed()]);
    await loading;
    await assertion;
    expect(repository.fetched, isEmpty);
    expect(repository.saves, isEmpty);
  });

  test('Concurrent adds serialize and do not lose either saved connection', () async {
    await controller.load();
    final pending = Completer<ReadingFeed>();
    repository.onFetch = (url) => url == 'feed-a'
        ? pending.future
        : Future.value(sampleFeed(url: url));
    final a = controller.addFeed('feed-a');
    final b = controller.addFeed('feed-b');
    await Future<void>.delayed(Duration.zero);
    expect(repository.fetched, ['feed-a']);
    pending.complete(sampleFeed());
    await Future.wait([a, b]);
    expect(controller.feeds.map((feed) => feed.url), ['feed-a', 'feed-b']);
    expect(repository.stored, controller.feeds);
    expect(repository.saves.map((feeds) => feeds.length), [1, 2]);
    expect(controller.busy, isFalse);
  });

  test('Equivalent concurrent shelf adds cannot duplicate or lose the original key', () async {
    await controller.load();
    const original = 'http://goodreads.com/review/list_rss/00123/?key=private&shelf=read';
    final first = controller.addFeed(original);
    final duplicate = expectLater(
      controller.addFeed('https://www.goodreads.com/review/list_rss/123?shelf=read'),
      throwsA(isA<FeedException>()),
    );
    await first;
    await duplicate;
    expect(repository.fetched, [original]);
    expect(controller.feeds.single.url, original);
    expect(repository.saves, hasLength(1));
  });

  test('Remove and add queued behind refresh use the latest saved snapshot', () async {
    final original = sampleFeed(books: [sampleBook(id: 'cached')]);
    repository.stored = [original];
    await controller.load();
    final pending = Completer<ReadingFeed>();
    repository.onFetch = (url) => url == 'feed-a'
        ? pending.future
        : Future.value(sampleFeed(url: url));
    final refreshing = controller.refresh();
    final removing = controller.removeFeed(original);
    final adding = controller.addFeed('feed-b');
    await Future<void>.delayed(Duration.zero);
    expect(repository.saves, isEmpty);
    pending.complete(sampleFeed(books: [sampleBook(id: 'fresh')]));
    await Future.wait([refreshing, removing, adding]);
    expect(repository.saves.map((feeds) => feeds.length), [1, 0, 1]);
    expect(controller.feeds.single.url, 'feed-b');
    expect(controller.books, isEmpty);
    expect(repository.stored, controller.feeds);
  });

  test('Failed queued persistence preserves old state and does not poison subsequent mutations', () async {
    final original = sampleFeed();
    repository.stored = [original];
    await controller.load();
    final pending = Completer<void>();
    var saves = 0;
    repository.onSave = (_) => ++saves == 1 ? pending.future : Future.value();
    final removing = expectLater(controller.removeFeed(original), throwsStateError);
    final adding = controller.addFeed('feed-b');
    await Future<void>.delayed(Duration.zero);
    expect(controller.feeds, [same(original)]);
    pending.completeError(StateError('disk full'));
    await removing;
    await adding;
    expect(controller.feeds.map((feed) => feed.url), ['feed-a', 'feed-b']);
    expect(repository.stored, controller.feeds);
    expect(controller.error, isNull);
    expect(controller.busy, isFalse);
  });

  test('Queued removal still identifies a legacy URL after refresh canonicalizes it', () async {
    const originalUrl = 'http://goodreads.com/review/list_rss/00123/?shelf=read&key=keep';
    const canonicalUrl = 'https://www.goodreads.com/review/list_rss/123?shelf=read&key=keep';
    final original = sampleFeed(url: originalUrl);
    repository.stored = [original];
    await controller.load();
    repository.onFetch = (_) async => sampleFeed(url: canonicalUrl);
    final refreshing = controller.refresh();
    final removing = controller.removeFeed(original);
    await Future.wait([refreshing, removing]);
    expect(controller.feeds, isEmpty);
    expect(repository.stored, isEmpty);
  });
}
