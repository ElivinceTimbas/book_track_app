import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:book_track_app/core/errors/month_export_exception.dart';
import 'package:book_track_app/core/theme/app_theme.dart';
import 'package:book_track_app/features/reading/domain/entities/book.dart';
import 'package:book_track_app/features/reading/domain/entities/calendar_month.dart';
import 'package:book_track_app/features/reading/domain/entities/month_image.dart';
import 'package:book_track_app/features/reading/domain/repositories/cover_source.dart';
import 'package:book_track_app/features/reading/presentation/widgets/export/month_image_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reading_fakes.dart';

class MemoryCovers implements CoverSource {
  final urls = <String>[];
  Future<Uint8List?> Function(String)? onLoad;
  bool disposed = false;
  int active = 0;
  int maxActive = 0;
  @override
  Future<Uint8List?> load(String url) async {
    urls.add(url);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      return await onLoad?.call(url);
    } finally {
      active--;
    }
  }

  @override
  void dispose() => disposed = true;
}

Future<Uint8List> paintedPng(
  int width,
  int height,
  void Function(Canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<Uint8List> solidPng(Color color) =>
    paintedPng(8, 12, (canvas) => canvas.drawColor(color, BlendMode.src));

class PngPixels {
  PngPixels(this.width, this.height, this.bytes);
  final int width;
  final int height;
  final Uint8List bytes;

  static Future<PngPixels> decode(MonthImage result) async {
    final codec = await ui.instantiateImageCodec(result.bytes);
    try {
      final image = (await codec.getNextFrame()).image;
      try {
        return PngPixels(
          image.width,
          image.height,
          (await image.toByteData())!.buffer.asUint8List(),
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  List<int> at(Offset logical) {
    final x = (logical.dx * MonthImageLayout.pixelRatio).floor();
    final y = (logical.dy * MonthImageLayout.pixelRatio).floor();
    final index = (y * width + x) * 4;
    return bytes.sublist(index, index + 4);
  }

  void expectSolid(Rect rect, List<int> rgba) {
    for (var y = rect.top; y < rect.bottom; y += 8) {
      for (var x = rect.left; x < rect.right; x += 8) {
        expect(at(Offset(x, y)), rgba, reason: 'Pixel at $x, $y');
      }
    }
  }
}

Book coverBook(
  String id,
  DateTime date, {
  String url = '',
  bool started = false,
}) => Book(
  id: id,
  title: 'Book $id',
  author: 'Author',
  status: ReadingStatus.toRead,
  coverUrl: url,
  readAt: started ? null : date,
  startedAt: started ? date : null,
);

const paperRgba = [248, 247, 243, 255];
const whiteRgba = [255, 255, 255, 255];
const activeRgba = [248, 249, 245, 255];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(MonthImageRenderer.loadFonts);

  test('Monday-first leap month sizes each week for every cover, no appendix space', () {
    final month = CalendarMonth(DateTime(2024, 2, 25), [
      for (var i = 0; i < 7; i++) coverBook('$i', DateTime(2024, 2, 1)),
      coverBook('last', DateTime(2024, 2, 29)),
      sampleBook(id: 'undated'),
    ]);
    final layout = MonthImageLayout(month);
    expect(layout.dayRect(1).left, 56 + 3 * 144);
    expect(layout.weeks.map((week) => week.height), [378, 132, 132, 132, 132]);
    expect(layout.dayRect(29).top, MonthImageLayout.gridTop + 378 + 3 * 132);
    expect(layout.coverRect(1, 0).size, const Size(48, 72));
    expect(layout.coverRect(1, 6).top - layout.coverRect(1, 0).top, 3 * 82);
    expect(layout.coverRect(1, 6).bottom, lessThan(layout.dayRect(1).bottom));
    expect(month.onDay(1).map((book) => book.id), [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
    ]);
    expect(layout.height, layout.gridBottom + 68);
    expect(layout.physicalHeight, layout.height * 2);
  });

  test('actual covers and all missing/failed placeholders occupy their dates in opaque 2x PNG', () async {
    final red = await solidPng(const Color(0xFFFF0000));
    final blue = await solidPng(const Color(0xFF0000FF));
    final source = MemoryCovers()
      ..onLoad = (url) async => switch (url) {
        'red' => red,
        'blue' => blue,
        'corrupt' => Uint8List.fromList([1, 2, 3]),
        'failed' => throw StateError('network failure'),
        _ => null,
      };
    final month = CalendarMonth(DateTime(2024, 2), [
      coverBook('a', DateTime(2024, 2, 1), url: 'red'),
      coverBook('b', DateTime(2024, 2, 1), url: 'blue', started: true),
      coverBook('c', DateTime(2024, 2, 1)),
      coverBook('d', DateTime(2024, 2, 1), url: 'corrupt'),
      coverBook('e', DateTime(2024, 2, 1), url: 'failed'),
      coverBook('f', DateTime(2024, 2, 29), url: 'blue'),
    ]);
    final renderer = MonthImageRenderer(source);
    addTearDown(renderer.dispose);
    final progress = <int>[];
    final result = await renderer.prepare(month, (done, total) {
      progress.add(done);
      expect(total, 6);
    });
    expect(progress, [0, 1, 2, 3, 4, 5, 6]);
    expect(result.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(source.urls, hasLength(6));
    expect(source.maxActive, lessThanOrEqualTo(4));
    final pixels = await PngPixels.decode(result);
    final layout = MonthImageLayout(month);
    expect(pixels.width, 2240);
    expect(result.width, pixels.width);
    expect(pixels.height, result.height);
    expect(result.height, layout.physicalHeight);
    expect(pixels.at(layout.coverRect(1, 0).center), [255, 0, 0, 255]);
    // Existing event order puts the started book after all four finished books.
    expect(pixels.at(layout.coverRect(1, 4).center), [0, 0, 255, 255]);
    expect(pixels.at(layout.coverRect(29, 0).center), [0, 0, 255, 255]);
    for (var i = 1; i <= 3; i++) {
      final rect = layout.coverRect(1, i);
      expect(pixels.at(Offset(rect.left + 3, rect.bottom - 20)), [
        237,
        240,
        231,
        255,
      ]);
    }
    expect(
      pixels.at(const Offset(60, MonthImageLayout.gridTop + 40)),
      whiteRgba,
    );
    expect(pixels.at(Offset.zero), paperRgba);
    expect(result.summary, contains('Finished: 5, Started: 1, Shelf date: 0'));
  });

  test('missing-cover title and full label remain unobstructed above the event badge', () async {
    const title =
        'A long placeholder title that must not collide with its label';
    final month = CalendarMonth(DateTime(2024, 2), [
      sampleBook(title: title, readAt: DateTime(2024, 2, 1)),
    ]);
    final renderer = MonthImageRenderer(MemoryCovers());
    addTearDown(renderer.dispose);
    final pixels = await PngPixels.decode(
      await renderer.prepare(month, (_, _) {}),
    );
    final cover = MonthImageLayout(month).coverRect(1, 0);
    final expectedBytes = await paintedPng(96, 144, (canvas) {
      canvas.scale(2);
      canvas.drawColor(softOlive, BlendMode.src);
      final titlePainter = exportText(title, 10, 42, maxLines: 3);
      final labelPainter = exportText('No cover', 9, 42, maxLines: 1);
      try {
        expect(4 + titlePainter.height, lessThanOrEqualTo(40));
        expect(40 + labelPainter.height, lessThanOrEqualTo(52));
        titlePainter.paint(canvas, const Offset(3, 4));
        labelPainter.paint(canvas, const Offset(3, 40));
      } finally {
        titlePainter.dispose();
        labelPainter.dispose();
      }
    });
    final expected = await PngPixels.decode(
      MonthImage(expectedBytes, 96, 144, ''),
    );
    var labelInk = 0;
    // Compare every physical pixel of both text bands, including the label's
    // right-hand letters that previously disappeared underneath the badge.
    for (var y = 4.0; y < 51; y += 0.5) {
      for (var x = 3.0; x < 45; x += 0.5) {
        final point = Offset(x, y);
        final reference = expected.at(point);
        expect(pixels.at(cover.topLeft + point), reference);
        if (y >= 40 && x >= 28 && reference[0] < 200) labelInk++;
      }
    }
    expect(labelInk, greaterThan(10));
    expect(pixels.at(Offset(cover.right - 1, cover.bottom - 1)), paperRgba);
  });

  test('six-week PNG contains every cover once inside last-day cell, without tally or overflow strips', () async {
    const colors = [
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFFFF00),
      Color(0xFFFF00FF),
      Color(0xFF00FFFF),
      Color(0xFF8080FF),
    ];
    final covers = [for (final color in colors) await solidPng(color)];
    final source = MemoryCovers()
      ..onLoad = (url) async => covers[int.parse(url)];
    final month = CalendarMonth(DateTime(2021, 5), [
      for (var i = 0; i < covers.length; i++)
        coverBook('$i', DateTime(2021, 5, 31), url: '$i'),
      // A busy first week shifts all subsequent weeks, including the last day.
      for (var i = 0; i < 5; i++) coverBook('early$i', DateTime(2021, 5, 1)),
    ]);
    final layout = MonthImageLayout(month);
    expect(month.weeks, 6);
    expect(layout.dayRect(31).top, MonthImageLayout.gridTop + 296 + 4 * 132);
    expect(layout.dayRect(31).left, 56);
    final renderer = MonthImageRenderer(source);
    addTearDown(renderer.dispose);
    final result = await renderer.prepare(month, (_, _) {});
    final pixels = await PngPixels.decode(result);
    for (var i = 0; i < covers.length; i++) {
      final color = colors[i];
      final rgba = [
        (color.toARGB32() >> 16) & 255,
        (color.toARGB32() >> 8) & 255,
        color.toARGB32() & 255,
        255,
      ];
      final rect = layout.coverRect(31, i);
      expect(layout.dayRect(31).contains(rect.bottomRight), isTrue);
      pixels.expectSolid(
        Rect.fromLTWH(rect.left + 2, rect.top + 2, 40, 48),
        rgba,
      );
      var matchingPixels = 0;
      for (var offset = 0; offset < pixels.bytes.length; offset += 4) {
        if (pixels.bytes[offset] == rgba[0] &&
            pixels.bytes[offset + 1] == rgba[1] &&
            pixels.bytes[offset + 2] == rgba[2]) {
          matchingPixels++;
        }
      }
      expect(
        matchingPixels,
        96 * 144 - 40 * 40,
        reason: 'Each solid cover appears exactly once, minus its individual badge.',
      );
    }
    final day = layout.dayRect(31);
    pixels.expectSolid(
      Rect.fromLTRB(
        day.left + 12,
        day.bottom - 18,
        day.right - 12,
        day.bottom - 6,
      ),
      activeRgba,
    );
    // The unused eighth slot is empty, not a tally or +N notice.
    pixels.expectSolid(layout.coverRect(31, 7).deflate(2), activeRgba);
    // June 1 remains blank and has a white surface.
    pixels.expectSolid(
      Rect.fromLTRB(
        day.right + 4,
        day.top + 4,
        day.right + 140,
        day.bottom - 4,
      ),
      whiteRgba,
    );
    expect(result.height, (layout.gridBottom + 68) * 2);
    expect(source.urls, hasLength(12));
  });

  test('rounded white card clips bottom grid edges, has one clean border and rounded active days', () async {
    final month = CalendarMonth(DateTime(2024, 2), [
      coverBook('a', DateTime(2024, 2, 1)),
    ]);
    final layout = MonthImageLayout(month);
    final renderer = MonthImageRenderer(MemoryCovers());
    addTearDown(renderer.dispose);
    final pixels = await PngPixels.decode(
      await renderer.prepare(month, (_, _) {}),
    );
    expect(layout.card.tlRadiusX, 30);
    for (final corner in [
      const Offset(57, 261),
      const Offset(1063, 261),
      Offset(57, layout.gridBottom - 1),
      Offset(1063, layout.gridBottom - 1),
    ]) {
      expect(pixels.at(corner), paperRgba);
    }
    expect(pixels.at(const Offset(90, 265)), whiteRgba);
    final lineRgba = [
      (line.toARGB32() >> 16) & 255,
      (line.toARGB32() >> 8) & 255,
      line.toARGB32() & 255,
      255,
    ];
    expect(pixels.at(const Offset(56, 300)), lineRgba);
    expect(pixels.at(const Offset(55, 300)), paperRgba);
    expect(pixels.at(const Offset(57, 300)), whiteRgba);
    // Shared grid edges have the same stroke width and color as the outer edge.
    expect(pixels.at(const Offset(200, 350)), lineRgba);
    expect(pixels.at(const Offset(199, 350)), whiteRgba);
    expect(pixels.at(const Offset(201, 350)), whiteRgba);
    final day = layout.dayRect(1);
    expect(pixels.at(Offset(day.right - 5, day.top + 5)), whiteRgba);
    expect(pixels.at(Offset(day.right - 12, day.top + 12)), activeRgba);
  });

  test('physical cover decoding preserves detail, fits crop and never upscales small sources', () async {
    expect(MonthImageRenderer.coverDecodeSize(480, 720), const Size(96, 144));
    expect(MonthImageRenderer.coverDecodeSize(400, 400), const Size(144, 144));
    expect(MonthImageRenderer.coverDecodeSize(8, 12), const Size(8, 12));
    expect(MonthImageRenderer.coverDecodeSize(12000, 1), const Size(512, 1));
    final stripes = await paintedPng(192, 288, (canvas) {
      for (var x = 0; x < 192; x += 2) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), 0, 2, 288),
          Paint()..color = x % 4 == 0 ? Colors.black : Colors.white,
        );
      }
    });
    final source = MemoryCovers()..onLoad = (_) async => stripes;
    final renderer = MonthImageRenderer(source);
    addTearDown(renderer.dispose);
    final month = CalendarMonth(DateTime(2024, 2), [
      coverBook('a', DateTime(2024, 2, 1)),
    ]);
    final pixels = await PngPixels.decode(
      await renderer.prepare(month, (_, _) {}),
    );
    final cover = MonthImageLayout(month).coverRect(1, 0);
    final samples = [
      for (var x = 2; x < 94; x++)
        pixels.at(Offset(cover.left + x / 2, cover.top + 10))[0],
    ];
    var sharpTransitions = 0;
    for (var i = 1; i < samples.length; i++) {
      if ((samples[i] - samples[i - 1]).abs() > 150) sharpTransitions++;
    }
    expect(
      sharpTransitions,
      greaterThan(80),
      reason: 'One-physical-pixel detail must survive, not an enlarged low-res cover.',
    );
  });

  test(
    'empty six-week month is compact and has no requests or fabricated entries',
    () async {
      final source = MemoryCovers();
      final renderer = MonthImageRenderer(source);
      addTearDown(renderer.dispose);
      final month = CalendarMonth(DateTime(2021, 5), [sampleBook()]);
      final image = await renderer.prepare(month, (_, _) {});
      final layout = MonthImageLayout(month);
      final pixels = await PngPixels.decode(image);
      expect(source.urls, isEmpty);
      expect(image.summary, contains('Finished: 0'));
      expect(month.weeks, 6);
      expect(image.width, 2240);
      expect(image.height, (312 + 6 * 132 + 108) * 2);
      expect(image.height, layout.physicalHeight);
      expect(pixels.at(layout.coverRect(31, 0).center), whiteRgba);
    },
  );

  test('book, physical pixel and axis limits reject before any cover loads, no legacy title/list limit', () async {
    final source = MemoryCovers();
    final renderer = MonthImageRenderer(source);
    addTearDown(renderer.dispose);
    for (final count in [101, 90, 50]) {
      final month = CalendarMonth(DateTime(2024, 2), [
        for (var i = 0; i < count; i++) coverBook('$i', DateTime(2024, 2, 1)),
      ]);
      await expectLater(
        renderer.prepare(
          month,
          (_, _) => fail('No progress before validation'),
        ),
        throwsA(
          isA<MonthExportException>().having(
            (error) => error.message,
            'neutral message',
            'This month has too many books for one image. No image was created and no books were omitted.',
          ),
        ),
      );
      expect(source.urls, isEmpty);
    }
    // All 100 books fit when distributed; even a six-week month needs no fallback resolution.
    final distributed = MonthImageLayout(
      CalendarMonth(DateTime(2021, 5), [
        for (var i = 0; i < 100; i++)
          coverBook('$i', DateTime(2021, 5, i ~/ 4 + 1)),
      ]),
    );
    expect(
      distributed.physicalHeight,
      lessThanOrEqualTo(MonthImageLayout.maxDimension),
    );
    expect(
      distributed.physicalHeight * 2240,
      lessThanOrEqualTo(MonthImageLayout.maxPixels),
    );
    final longTitle = MonthImageLayout(
      CalendarMonth(DateTime(2024, 2), [
        sampleBook(title: 'long ' * 1000, addedAt: DateTime(2024, 2)),
      ]),
    );
    expect(longTitle.height, 312 + 5 * 132 + 68);
  });

  test(
    'disposal cancels preparation; no late progress and source closed',
    () async {
      final pending = Completer<Uint8List?>();
      final source = MemoryCovers()..onLoad = (_) => pending.future;
      final renderer = MonthImageRenderer(source);
      final progress = <int>[];
      final preparation = renderer.prepare(
        CalendarMonth(DateTime(2024, 2), [coverBook('a', DateTime(2024, 2))]),
        (done, _) => progress.add(done),
      );
      await Future<void>.delayed(Duration.zero);
      renderer.dispose();
      pending.complete(null);
      await expectLater(preparation, throwsA(isA<MonthExportException>()));
      expect(source.disposed, isTrue);
      expect(progress, [0]);
    },
  );
}
