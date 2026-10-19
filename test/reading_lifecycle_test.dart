import 'dart:async';

import 'package:book_track_app/features/reading/domain/reading_feed.dart';
import 'package:book_track_app/features/reading/presentation/reading_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_fakes.dart';

void main() {
  test(
    'Disposal during load prevents late state changes and notifications',
    () async {
      final pending = Completer<List<ReadingFeed>>();
      final repository = FakeReadingRepository()..onLoad = () => pending.future;
      final controller = ReadingController(repository: repository);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final loading = controller.load();
      await Future<void>.delayed(Duration.zero);
      notifications = 0;
      controller.dispose();
      pending.complete([sampleFeed()]);
      await loading;
      expect(controller.feeds, isEmpty);
      expect(notifications, 0);
    },
  );

  test('Load failure after disposal is handled without notifying', () async {
    final pending = Completer<List<ReadingFeed>>();
    final repository = FakeReadingRepository()..onLoad = () => pending.future;
    final controller = ReadingController(repository: repository);
    final loading = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    pending.completeError(StateError('closed'));
    await loading;
    expect(controller.error, isNull);
  });

  test('Disposal during add fetch skips persistence and publishing', () async {
    final pending = Completer<ReadingFeed>();
    final repository = FakeReadingRepository()..onFetch = (_) => pending.future;
    final controller = ReadingController(repository: repository);
    await controller.load();
    final adding = controller.addFeed('feed-a');
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    pending.complete(sampleFeed());
    await adding;
    expect(repository.saves, isEmpty);
    expect(controller.feeds, isEmpty);
  });

  test(
    'Disposal during refresh stops subsequent requests and persistence',
    () async {
      final pending = Completer<ReadingFeed>();
      final repository = FakeReadingRepository()
        ..stored = [sampleFeed(), sampleFeed(url: 'feed-b')]
        ..onFetch = (_) => pending.future;
      final controller = ReadingController(repository: repository);
      await controller.load();
      final refreshing = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      pending.completeError(StateError('client closed'));
      await refreshing;
      expect(repository.fetched, ['feed-a']);
      expect(repository.saves, isEmpty);
    },
  );

  for (final operation in ['add', 'remove', 'refresh']) {
    test('Disposal during $operation save does not publish or notify', () async {
      final pending = Completer<void>();
      final original = sampleFeed();
      final repository = FakeReadingRepository()
        ..stored = [original]
        ..onSave = (_) => pending.future;
      final controller = ReadingController(repository: repository);
      await controller.load();
      final action = switch (operation) {
        'add' => controller.addFeed('feed-b'),
        'remove' => controller.removeFeed(original),
        _ => controller.refresh(),
      };
      await Future<void>.delayed(Duration.zero);
      expect(repository.saves, hasLength(1));
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      pending.complete();
      await action;
      expect(controller.feeds, [same(original)]);
      expect(notifications, 0);
      // Already-issued writes are allowed to finish; disposal is not rollback.
      expect(repository.stored, repository.saves.single);
    });
  }

  test('Methods invoked after disposal do not access the repository', () async {
    final repository = FakeReadingRepository()
      ..onLoad = () => throw StateError('must not be called');
    final controller = ReadingController(repository: repository)..dispose();
    await controller.load();
    await controller.addFeed('feed-a');
    await controller.removeFeed(sampleFeed());
    await controller.refresh();
    expect(repository.normalized, isEmpty);
    expect(repository.fetched, isEmpty);
    expect(repository.saves, isEmpty);
  });

  test('Disposal drops queued mutations as well as late active fetch results', () async {
    final pending = Completer<ReadingFeed>();
    final repository = FakeReadingRepository()
      ..onFetch = (_) => pending.future;
    final controller = ReadingController(repository: repository);
    await controller.load();
    final first = controller.addFeed('feed-a');
    final queued = controller.addFeed('feed-b');
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    pending.complete(sampleFeed());
    await Future.wait([first, queued]);
    expect(repository.fetched, ['feed-a']);
    expect(repository.saves, isEmpty);
    expect(controller.feeds, isEmpty);
  });
}
