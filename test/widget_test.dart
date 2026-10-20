import 'dart:async';

import 'package:book_track_app/app/folio_app.dart';
import 'package:book_track_app/core/di/bootstrap.dart';
import 'package:book_track_app/core/errors/feed_exception.dart';
import 'package:book_track_app/features/reading/domain/entities/book.dart';
import 'package:book_track_app/features/reading/domain/entities/reading_feed.dart';
import 'package:book_track_app/features/reading/domain/usecases/reading_library.dart';
import 'package:book_track_app/features/reading/presentation/blocs/reading/reading_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/reading_fakes.dart';

Future<ReadingCubit> mountReadingApp(WidgetTester tester, FakeReadingRepository repository) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = ReadingCubit(library: ReadingLibrary(repository: repository));
  addTearDown(controller.close);
  await controller.load();
  await tester.pumpWidget(FolioApp(cubit: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final font in {'Lora': 'Lora.ttf', 'DM Sans': 'DMSans.ttf'}.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Pending cache load shows loading rather than books or a connection form', (tester) async {
    final pending = Completer<List<ReadingFeed>>();
    final repository = FakeReadingRepository()..onLoad = () => pending.future;
    final controller = ReadingCubit(library: ReadingLibrary(repository: repository));
    addTearDown(controller.close);
    final loading = controller.load();
    await tester.pumpWidget(FolioApp(cubit: controller));
    await tester.pump();
    expect(find.text('Loading saved shelves…'), findsOneWidget);
    expect(find.text('Connect Goodreads'), findsNothing);
    expect(controller.books, isEmpty);
    pending.complete([]);
    await loading;
    await tester.pumpAndSettle();
    expect(find.text('Not connected'), findsOneWidget);
    expect(controller.books, isEmpty);
  });

  testWidgets('Default connection fetches and saves before success; busy form cannot submit or dismiss', (tester) async {
    final fetched = Completer<ReadingFeed>();
    final saved = Completer<void>();
    final repository = FakeReadingRepository()
      ..onFetch = ((_) => fetched.future)
      ..onSave = (_) => saved.future;
    final controller = await mountReadingApp(tester, repository);
    await tester.tap(find.text('Connect Goodreads'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goodreads-original-url')), findsNothing);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('goodreads-user-id'))).controller!.text, isEmpty);
    expect(find.text('Read'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('goodreads-user-id')), '123');
    await tester.tap(find.text('Connect my shelf'));
    await tester.pump();
    expect(repository.fetched, ['https://www.goodreads.com/review/list_rss/123?shelf=read']);
    expect(repository.saves, isEmpty);
    expect(controller.feeds, isEmpty);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('goodreads-user-id'))).enabled, isFalse);
    expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Close'), matching: find.byType(IconButton))).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Connecting your shelf…')).onPressed, isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.text('Bring your books along.'), findsOneWidget);
    final context = tester.element(find.text('Bring your books along.'));
    await Navigator.of(context).maybePop();
    await tester.pump();
    expect(find.text('Bring your books along.'), findsOneWidget);
    fetched.complete(sampleFeed(url: repository.fetched.single));
    await tester.pump();
    expect(repository.saves, hasLength(1));
    expect(controller.feeds, isEmpty);
    expect(find.text('Bring your books along.'), findsOneWidget);
    saved.complete();
    await tester.pumpAndSettle();
    expect(find.text('Bring your books along.'), findsNothing);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Shelf connected, no books returned.'), findsOneWidget);
    expect(controller.books, isEmpty);
    expect(repository.stored, controller.feeds);
  });

  testWidgets('Connection fetch and save errors preserve input and allow retry, then last disconnect is empty', (tester) async {
    final repository = FakeReadingRepository()
      ..onFetch = (_) async => throw const FeedException('This public shelf is unavailable.');
    final controller = await mountReadingApp(tester, repository);
    await tester.tap(find.text('Connect Goodreads'));
    await tester.pumpAndSettle();
    final id = find.byKey(const ValueKey('goodreads-user-id'));
    await tester.enterText(id, '123');
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    expect(find.text('This public shelf is unavailable.'), findsWidgets);
    expect(tester.widget<TextFormField>(id).controller!.text, '123');
    expect(repository.saves, isEmpty);
    repository.onFetch = (url) async => sampleFeed(url: url, books: [sampleBook(title: 'A real fixture')]);
    repository.onSave = (_) async => throw StateError('disk full');
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    expect(find.text('We couldn’t save this feed. Please try again.'), findsOneWidget);
    expect(tester.widget<TextFormField>(id).controller!.text, '123');
    expect(controller.feeds, isEmpty);
    repository.onSave = null;
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    expect(controller.books.single.title, 'A real fixture');
    await tester.tap(find.text('Your feeds'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove feed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(controller.books, isEmpty);
    expect(repository.stored, isEmpty);
    expect(find.text('Not connected'), findsOneWidget);
    await tester.tap(find.text('My books'));
    await tester.pumpAndSettle();
    expect(find.text('Your library is empty.'), findsOneWidget);
    expect(find.text('A real fixture'), findsNothing);
  });

  testWidgets('Only active connection fields validate; original RSS retains optional query params', (tester) async {
    final repository = FakeReadingRepository();
    await mountReadingApp(tester, repository);
    await tester.tap(find.text('Connect Goodreads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a positive numeric Goodreads user ID.'), findsOneWidget);
    await tester.tap(find.text('Use an original RSS link instead'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paste a Goodreads shelf RSS link'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('goodreads-original-url')), 'http://goodreads.com/review/list_rss/123/?shelf=read&key=a%2Bb&x=1&x=2');
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    final uri = Uri.parse(repository.fetched.single);
    expect(uri.scheme, 'https');
    expect(uri.query, 'shelf=read&key=a%2Bb&x=1&x=2');
    expect(repository.stored.single.url, repository.fetched.single);
    expect(find.text('Bring your books along.'), findsNothing);
    await tester.tap(find.text('Your feeds'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a%2Bb'), findsNothing);
    expect(find.text('User 123 · Shelf: read'), findsOneWidget);
  });

  testWidgets('Custom shelf requires a slug and safely encodes its value', (tester) async {
    final repository = FakeReadingRepository();
    await mountReadingApp(tester, repository);
    await tester.tap(find.text('Connect Goodreads'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('goodreads-user-id')), '123');
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom shelf').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a custom shelf slug.'), findsOneWidget);
    expect(repository.fetched, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('goodreads-custom-shelf')), 'favorites&key=not-a-key');
    await tester.tap(find.text('Connect my shelf'));
    await tester.pumpAndSettle();
    expect(Uri.parse(repository.fetched.single).queryParameters, {'shelf': 'favorites&key=not-a-key'});
  });

  testWidgets('Cache failure is persistent on all pages and retry restores saved books without writes', (tester) async {
    final repository = FakeReadingRepository()
      ..stored = [sampleFeed(books: [sampleBook(title: 'Saved book')])]
      ..onLoad = () async => throw StateError('unreadable');
    await mountReadingApp(tester, repository);
    for (final page in ['Calendar', 'My books', 'Your feeds']) {
      await tester.tap(find.text(page));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your saved data has not been overwritten.'), findsOneWidget);
      expect(find.text('Retry loading saved shelves'), findsOneWidget);
      expect(find.text('Connect Goodreads'), findsNothing);
    }
    expect(repository.saves, isEmpty);
    repository.onLoad = null;
    await tester.tap(find.text('Retry loading saved shelves'));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    await tester.tap(find.text('My books'));
    await tester.pumpAndSettle();
    expect(find.text('Saved book'), findsWidgets);
    expect(repository.saves, isEmpty);
  });

  testWidgets('Failed refresh keeps cached books and persistent errors through navigation', (tester) async {
    final repository = FakeReadingRepository()
      ..stored = [sampleFeed(books: [sampleBook(title: 'Cached book')])]
      ..onFetch = (_) async => throw const FeedException('offline');
    await mountReadingApp(tester, repository);
    await tester.tap(find.text('Your feeds'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh all feeds'));
    await tester.pumpAndSettle();
    for (final page in ['Calendar', 'My books', 'Your feeds']) {
      await tester.tap(find.text(page));
      await tester.pumpAndSettle();
      expect(find.textContaining('Previously saved books are still available.'), findsWidgets);
    }
    expect(repository.stored.single.books.single.title, 'Cached book');
  });

  for (final size in [
    const Size(390, 844),
    const Size(1400, 1000),
    const Size(320, 740),
  ]) {
    testWidgets('Calendar and connection flow fit ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ReadingApplication());
      await tester.pumpAndSettle();

      expect(find.text('Your reading, at a glance.'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('The Midnight Library'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Connect Goodreads'));
      await tester.pumpAndSettle();
      expect(find.text('Bring your books along.'), findsOneWidget);
      await tester.ensureVisible(find.text('Connect my shelf'));
      await tester.tap(find.text('Connect my shelf'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enter a positive numeric Goodreads user ID.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byTooltip('Close'));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Next month'));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(
        find.text(
          DateFormat('MMMM yyyy').format(DateTime(now.year, now.month + 1)),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Library searches titles and feeds screen offers connection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ReadingCubit(library: ReadingLibrary(repository: FakeReadingRepository()
      ..stored = [sampleFeed(books: [sampleBook(title: 'The Midnight Library'), sampleBook(id: 'other', title: 'The Creative Act')])]));
    addTearDown(controller.close);
    await controller.load();
    await tester.pumpWidget(FolioApp(cubit: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My books'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'midnight');
    await tester.pumpAndSettle();
    expect(find.text('The Midnight Library'), findsWidgets);
    expect(find.text('The Creative Act'), findsNothing);
    await tester.tap(find.text('The Midnight Library').last);
    await tester.pumpAndSettle();
    expect(find.text('From your public Goodreads shelf.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close book details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your feeds'));
    await tester.pumpAndSettle();
    expect(find.text('Add Goodreads feed'), findsOneWidget);
    await tester.tap(find.text('My books'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'midnight');
    expect(find.text('The Creative Act'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('The Creative Act'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1400, 1000),
  ]) {
    testWidgets(
      'Connected library, details, filters and feeds fit ${size.width}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now();
        final repository = FakeReadingRepository()
          ..stored = [
            sampleFeed(
              url: 'https://www.goodreads.com/review/list_rss/123?shelf=all&key=long-public-feed-key',
              books: [
                sampleBook(
                  id: 'dated',
                  title: 'Finished chapter',
                  status: ReadingStatus.finished,
                  readAt: DateTime(now.year, now.month, 7),
                ),
                sampleBook(id: 'undated', title: 'Undated chapter'),
              ],
            ),
          ];
        final controller = ReadingCubit(library: ReadingLibrary(repository: repository));
        addTearDown(controller.close);
        await controller.load();
        await tester.pumpWidget(FolioApp(cubit: controller));
        await tester.pumpAndSettle();
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Undated chapter'), findsNothing);

        await tester.tap(find.text('My books'));
        await tester.pumpAndSettle();
        expect(find.text('Undated chapter'), findsWidgets);
        await tester.ensureVisible(find.text('Undated chapter').last);
        await tester.tap(find.text('Undated chapter').last);
        await tester.pumpAndSettle();
        expect(find.text('From your public Goodreads shelf.'), findsOneWidget);
        expect(find.textContaining('Added to shelf'), findsNothing);
        await tester.tap(find.byTooltip('Close book details'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Finished'));
        await tester.tap(find.widgetWithText(ChoiceChip, 'Finished'));
        await tester.pumpAndSettle();
        expect(find.text('Undated chapter'), findsNothing);
        expect(find.text('Finished chapter'), findsWidgets);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'AN AUTHOR');
        await tester.pumpAndSettle();
        expect(find.text('Finished chapter'), findsWidgets);

        await tester.tap(find.text('Your feeds'));
        await tester.pumpAndSettle();
        expect(find.text('A shelf'), findsOneWidget);
        expect(find.textContaining('long-public-feed-key'), findsNothing);
        expect(find.text('User 123 · Shelf: all'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Refresh all feeds'));
        await tester.tap(find.byTooltip('Refresh all feeds'));
        await tester.pumpAndSettle();
        expect(repository.fetched, [repository.stored.single.url]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
