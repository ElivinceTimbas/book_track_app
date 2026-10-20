import 'dart:async';

import 'package:book_track_app/core/errors/month_export_exception.dart';
import 'package:book_track_app/core/theme/app_theme.dart';
import 'package:book_track_app/features/reading/data/repositories/share_plus_image_sharer.dart';
import 'package:book_track_app/features/reading/domain/entities/book.dart';
import 'package:book_track_app/features/reading/domain/entities/calendar_month.dart';
import 'package:book_track_app/features/reading/domain/entities/month_image.dart';
import 'package:book_track_app/features/reading/domain/repositories/month_exporter.dart';
import 'package:book_track_app/features/reading/presentation/blocs/month_share/month_share_cubit.dart';
import 'package:book_track_app/features/reading/presentation/blocs/month_share/month_share_state.dart';
import 'package:book_track_app/features/reading/presentation/pages/calendar_page.dart';
import 'package:book_track_app/features/reading/presentation/widgets/calendar_event_badge.dart';
import 'package:book_track_app/features/reading/presentation/widgets/dialogs/share_month_dialog.dart';
import 'package:book_track_app/features/reading/presentation/widgets/export/month_image_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

import 'month_export_test.dart' show MemoryCovers, PngPixels;
import 'support/reading_fakes.dart';

class StubExporter implements MonthExporter {
  StubExporter(this.image);
  final MonthImage image;
  Future<MonthImage> Function(CalendarMonth, void Function(int, int))?
  onPrepare;
  final months = <CalendarMonth>[];
  bool disposed = false;
  @override
  Future<MonthImage> prepare(
    CalendarMonth month,
    void Function(int, int) progress,
  ) async {
    months.add(month);
    return onPrepare == null ? image : await onPrepare!(month, progress);
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List png;
  late MonthImage image;
  final month = CalendarMonth(DateTime(2024, 2, 23), []);
  const origin = Rect.fromLTWH(20, 30, 120, 48);
  setUpAll(() async {
    final renderer = MonthImageRenderer(MemoryCovers());
    try {
      image = await renderer.prepare(month, (_, _) {});
      png = image.bytes;
    } finally {
      renderer.dispose();
    }
  });

  test('share sends PNG/filename/summary/nonzero origin once, distinguishes cancellation', () async {
    final pending = Completer<ShareResult>();
    final params = <ShareParams>[];
    final exporter = StubExporter(image);
    final cubit = MonthShareCubit(
      month,
      exporter,
      SharePlusImageSharer(
        share: (value) {
          params.add(value);
          return pending.future;
        },
      ),
    );
    addTearDown(cubit.close);
    await cubit.prepare();
    final sharing = cubit.share(origin);
    await cubit.share(origin);
    expect(params, hasLength(1));
    expect(params.single.files!.single.mimeType, 'image/png');
    expect(await params.single.files!.single.readAsBytes(), png);
    expect((await PngPixels.decode(image)).width, 2240);
    expect(params.single.fileNameOverrides, ['folio-2024-02.png']);
    expect(params.single.sharePositionOrigin, origin);
    expect(params.single.text, image.summary);
    pending.complete(const ShareResult('', ShareResultStatus.dismissed));
    await sharing;
    expect(cubit.state.message, 'Sharing cancelled.');
    expect(cubit.state.phase, MonthSharePhase.ready);
    await cubit.share(Rect.zero);
    expect(params, hasLength(1));
  });

  test('duplicate preparation ignored, progress, inline error and retry retain snapshot', () async {
    final pending = Completer<MonthImage>();
    final exporter = StubExporter(image)
      ..onPrepare = (_, progress) {
        progress(1, 2);
        return pending.future;
      };
    final cubit = MonthShareCubit(
      month,
      exporter,
      SharePlusImageSharer(share: (_) async => ShareResult.unavailable),
    );
    addTearDown(cubit.close);
    final preparing = cubit.prepare();
    await cubit.prepare();
    expect(cubit.state.completed, 1);
    expect(exporter.months, [month]);
    pending.completeError(const MonthExportException('Try a smaller month.'));
    await preparing;
    expect(cubit.state.message, 'Try a smaller month.');
    expect(cubit.state.phase, MonthSharePhase.failed);
    exporter.onPrepare = null;
    await cubit.prepare();
    expect(cubit.state.image, image);
    expect(exporter.months, [month, month]);
    await cubit.share(origin);
    expect(cubit.state.message, contains('could not be confirmed'));
  });

  test('MissingPlugin and platform failures are useful/retryable, no false success', () async {
    var calls = 0;
    final cubit = MonthShareCubit(
      month,
      StubExporter(image),
      SharePlusImageSharer(
        share: (_) async {
          if (calls++ == 0) throw MissingPluginException();
          if (calls == 2) throw PlatformException(code: 'unavailable');
          return const ShareResult('target', ShareResultStatus.success);
        },
      ),
    );
    addTearDown(cubit.close);
    await cubit.prepare();
    await cubit.share(origin);
    expect(cubit.state.message, contains('full app rebuild'));
    await cubit.share(origin);
    expect(cubit.state.message, contains('couldn’t open'));
    await cubit.share(origin);
    expect(cubit.state.message, 'Share action selected.');
  });

  test(
    'dispose ignores late preparation and share completion; releases exporter',
    () async {
      final pending = Completer<MonthImage>();
      final exporter = StubExporter(image)
        ..onPrepare = (_, _) => pending.future;
      final cubit = MonthShareCubit(
        month,
        exporter,
        SharePlusImageSharer(share: (_) async => ShareResult.unavailable),
      );
      final preparing = cubit.prepare();
      await cubit.close();
      pending.complete(image);
      await preparing;
      expect(cubit.state.image, isNull);
      expect(exporter.disposed, isTrue);
      final sharePending = Completer<ShareResult>();
      final other = MonthShareCubit(
        month,
        StubExporter(image),
        SharePlusImageSharer(share: (_) => sharePending.future),
      );
      await other.prepare();
      final sharing = other.share(origin);
      await other.close();
      sharePending.complete(const ShareResult('', ShareResultStatus.success));
      await sharing;
      expect(other.state.message, isNull);
    },
  );

  for (final width in [320.0, 390.0, 1400.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'calendar mixed markers and legend accessible at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 2000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final date = DateTime(2024, 2, 29);
          await tester.pumpWidget(
            MaterialApp(
              theme: folioTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 2000),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: CalendarPage(
                      allBooks: [
                        sampleBook(id: 'f', readAt: date),
                        sampleBook(id: 's', startedAt: date),
                        sampleBook(id: 'a', addedAt: date),
                      ],
                      month: DateTime(2024, 2, 22),
                      selectedDay: date,
                      hasFeeds: true,
                      onConnect: () {},
                      onMonthChanged: (_) {},
                      onDaySelected: (_) {},
                      onBook: (_) {},
                      onShareMonth: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel(
              RegExp(
                'February 29, 2024, 3 reading events, Finished: 1, Started: 1, Shelf date: 1',
              ),
            ),
            findsOneWidget,
          );
          final legend = find.byType(CalendarLegend);
          await tester.ensureVisible(legend);
          await tester.pump();
          for (final event in CalendarEvent.values) {
            final badge = find.descendant(
              of: legend,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is CalendarEventBadge && widget.event == event,
              ),
            );
            expect(badge, findsOneWidget);
            expect(
              find.descendant(of: badge, matching: find.byIcon(event.icon)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: badge, matching: find.text(event.label)),
              findsOneWidget,
            );
          }
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Share month snapshots viewed month/all books, selected day and later refresh ignored',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final exporter = StubExporter(image);
      final pending = Completer<MonthImage>();
      exporter.onPrepare = (_, progress) {
        progress(0, 2);
        return pending.future;
      };
      final shared = <ShareParams>[];
      var viewed = DateTime(2024, 2, 23);
      var books = [
        sampleBook(id: 'one', readAt: DateTime(2024, 2, 1)),
        sampleBook(id: 'two', startedAt: DateTime(2024, 2, 29)),
        sampleBook(id: 'undated'),
      ];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: folioTheme(),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: SingleChildScrollView(
                  child: CalendarPage(
                    allBooks: books,
                    month: viewed,
                    selectedDay: DateTime(2024, 2, 1),
                    hasFeeds: true,
                    onConnect: () {},
                    onMonthChanged: (_) {},
                    onDaySelected: (_) {},
                    onBook: (_) {},
                    onShareMonth: (snapshot) => showDialog<void>(
                      context: context,
                      builder: (_) => ShareMonthDialog(
                        create: () => MonthShareCubit(
                          snapshot,
                          exporter,
                          SharePlusImageSharer(
                            share: (params) async {
                              shared.add(params);
                              return const ShareResult(
                                '',
                                ShareResultStatus.dismissed,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.ensureVisible(find.text('Share month'));
      await tester.tap(find.text('Share month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Share February 2024'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(exporter.months.single.books.map((book) => book.id), [
        'one',
        'two',
      ]);
      update(() {
        books = [];
        viewed = DateTime(2025, 6);
      });
      await tester.pump();
      pending.complete(image);
      await tester.pumpAndSettle();
      expect(find.text('Share February 2024'), findsOneWidget);
      expect(
        find.textContaining('No account IDs, feed URLs or keys'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Share image'));
      final rect = tester.getRect(
        find.widgetWithText(FilledButton, 'Share image'),
      );
      await tester.tap(find.text('Share image'));
      await tester.pumpAndSettle();
      expect(shared, hasLength(1));
      expect(shared.single.fileNameOverrides, ['folio-2024-02.png']);
      expect(shared.single.sharePositionOrigin, rect);
      expect(rect.isEmpty, isFalse);
      expect(find.text('Sharing cancelled.'), findsOneWidget);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(exporter.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview preparation failure/retry and closing while pending are safe',
    (tester) async {
      final pending = Completer<MonthImage>();
      final exporter = StubExporter(image)
        ..onPrepare = (_, _) async =>
            throw const MonthExportException('Image failed.');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareMonthDialog(
              create: () => MonthShareCubit(
                month,
                exporter,
                SharePlusImageSharer(
                  share: (_) async => ShareResult.unavailable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Image failed.'), findsOneWidget);
      exporter.onPrepare = (_, _) => pending.future;
      await tester.tap(find.text('Retry image'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      pending.complete(image);
      await tester.pumpAndSettle();
      expect(exporter.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large day counts stay on one line at 2x; calendar can scroll without shrinking text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: CalendarPage(
                  allBooks: [
                    for (var i = 0; i < 130; i++)
                      sampleBook(id: '$i', addedAt: DateTime(2024, 2, 1)),
                  ],
                  month: DateTime(2024, 2),
                  selectedDay: null,
                  hasFeeds: true,
                  onConnect: () {},
                  onMonthChanged: (_) {},
                  onDaySelected: (_) {},
                  onBook: (_) {},
                  onShareMonth: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Scroll calendar sideways for larger text.'),
        findsOneWidget,
      );
      expect(find.text('130'), findsOneWidget);
      expect(tester.getSize(find.text('130')).height, lessThan(40));
      expect(tester.widget<Text>(find.text('130')).style!.fontSize, 13);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default preview launcher prevents duplicate dialogs and cancellation releases resources',
    (tester) async {
      final pending = Completer<MonthImage>();
      final exporter = StubExporter(image)
        ..onPrepare = (_, _) => pending.future;
      var created = 0;
      GetIt.instance.registerFactoryParam<MonthShareCubit, CalendarMonth, void>(
        (snapshot, _) {
          created++;
          return MonthShareCubit(
            snapshot,
            exporter,
            SharePlusImageSharer(share: (_) async => ShareResult.unavailable),
          );
        },
      );
      addTearDown(() => GetIt.instance.reset());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  showShareMonth(context, month);
                  showShareMonth(context, month);
                },
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(created, 1);
      expect(find.byType(ShareMonthDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      pending.complete(image);
      await tester.pumpAndSettle();
      expect(exporter.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no visible list; image semantics retain full titles/dates/events at 320px and 200% text, original PNG is shared',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.runAsync(() async {
          for (final font in {
            'Lora': 'Lora.ttf',
            'DM Sans': 'DMSans.ttf',
          }.entries) {
            await (FontLoader(
              font.key,
            )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
          }
        });
        const title =
            'À travers les étoiles — 読書の記録 🌙: '
            'a very long, unabridged title about memory, belonging and quiet discoveries; '
            'the final chapter must remain fully readable — 終わりではなく、新しい始まり。';
        const author = 'Zoë García — 山田 花子';
        final books = [
          Book(
            id: 'hidden-account-probe',
            title: title,
            author: author,
            status: ReadingStatus.toRead,
            coverUrl: 'https://private.example/feed?key=hidden-key-probe',
            readAt: DateTime(2024, 2, 1),
          ),
          sampleBook(
            id: 'started',
            title: 'A beginning — Début',
            startedAt: DateTime(2024, 2, 15),
          ),
          sampleBook(
            id: 'shelf',
            title: 'A shelf date — 本棚',
            addedAt: DateTime(2024, 2, 29),
          ),
          sampleBook(id: 'undated', title: 'Not included'),
        ];
        final snapshot = CalendarMonth(DateTime(2024, 2, 20), books);
        final exporter = StubExporter(image);
        final shared = <ShareParams>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: folioTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: ShareMonthDialog(
                  create: () => MonthShareCubit(
                    snapshot,
                    exporter,
                    SharePlusImageSharer(
                      share: (params) async {
                        shared.add(params);
                        return const ShareResult(
                          '',
                          ShareResultStatus.dismissed,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        books.clear();
        expect(find.text('Books included in this image'), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        await tester.ensureVisible(find.byType(Image));
        await tester.pumpAndSettle();
        final preview = tester.widget<Image>(find.byType(Image));
        expect(preview.image, isA<ResizeImage>());
        expect((preview.image as ResizeImage).width, 640);
        final expected = [
          (
            title: title,
            author: author,
            date: 'February 1, 2024',
            event: 'Finished',
          ),
          (
            title: 'A beginning — Début',
            author: 'An author',
            date: 'February 15, 2024',
            event: 'Started',
          ),
          (
            title: 'A shelf date — 本棚',
            author: 'An author',
            date: 'February 29, 2024',
            event: 'Shelf date',
          ),
        ];
        for (final entry in expected) {
          final description =
              '${entry.title}\n${entry.author}\n${entry.date}\n${entry.event}';
          expect(
            find.bySemanticsLabel(RegExp(RegExp.escape(description))),
            findsOneWidget,
          );
          expect(preview.semanticLabel, contains(description));
          expect(find.text(entry.title), findsNothing);
          expect(find.text(entry.date), findsNothing);
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Not included'), findsNothing);
        final visibleText = tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data ?? '')
            .join('\n');
        expect(visibleText, isNot(contains('hidden-account-probe')));
        expect(visibleText, isNot(contains('hidden-key-probe')));
        expect(visibleText, isNot(contains('private.example')));
        expect(preview.semanticLabel, isNot(contains('hidden-account-probe')));
        expect(preview.semanticLabel, isNot(contains('hidden-key-probe')));
        expect(preview.semanticLabel, isNot(contains('private.example')));
        expect(preview.semanticLabel, isNot(contains('Not included')));
        await tester.ensureVisible(find.text('Share image'));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('Share image')).bottom, lessThan(800));
        final rect = tester.getRect(
          find.widgetWithText(FilledButton, 'Share image'),
        );
        await tester.tap(find.text('Share image'));
        await tester.pumpAndSettle();
        expect(shared, hasLength(1));
        expect(shared.single.fileNameOverrides, ['folio-2024-02.png']);
        expect(shared.single.files!.single.mimeType, 'image/png');
        expect(await shared.single.files!.single.readAsBytes(), png);
        expect(shared.single.sharePositionOrigin, rect);
        expect(rect.isEmpty, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(exporter.disposed, isTrue);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'empty preview has no list and explains its empty image in semantics',
    (tester) async {
      final exporter = StubExporter(image);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareMonthDialog(
              create: () => MonthShareCubit(
                month,
                exporter,
                SharePlusImageSharer(
                  share: (_) async => ShareResult.unavailable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Books included in this image'), findsNothing);
      expect(
        tester.widget<Image>(find.byType(Image)).semanticLabel,
        contains('No recorded book dates this month.'),
      );
      expect(find.text(image.summary), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
