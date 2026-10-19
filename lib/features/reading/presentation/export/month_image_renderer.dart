import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../domain/book.dart';
import '../../domain/calendar_month.dart';
import '../../domain/month_export.dart';
import '../widgets/calendar_event_badge.dart';

const _tooLarge = MonthExportException(
  'This month has too many books for one image. '
  'No image was created and no books were omitted.',
);

class MonthImageLayout {
  MonthImageLayout(this.month) {
    if (month.books.length > 100) throw _tooLarge;
    var y = gridTop;
    for (var week = 0; week < month.weeks; week++) {
      var rows = 1;
      for (var column = 0; column < 7; column++) {
        final day = week * 7 + column - month.leadingDays + 1;
        rows = math.max(rows, (month.onDay(day).length / 2).ceil());
      }
      final height = 50.0 + rows * coverRowHeight;
      weeks.add((top: y, height: height));
      y += height;
    }
    gridBottom = y;
    height = (gridBottom + (month.books.isEmpty ? 108 : 68)).ceil();
    if (physicalWidth > maxDimension ||
        physicalHeight > maxDimension ||
        physicalWidth * physicalHeight > maxPixels) {
      throw _tooLarge;
    }
  }

  static const width = 1120;
  static const pixelRatio = 2;
  static const physicalWidth = width * pixelRatio;
  static const maxDimension = 8192;
  static const maxPixels = 12000000;
  static const gridTop = 312.0;
  static const coverRowHeight = 82.0;
  static const cardRadius = 30.0;
  static const dayRadius = 8.0;
  final CalendarMonth month;
  final weeks = <({double top, double height})>[];
  late final double gridBottom;
  late final int height;
  int get physicalHeight => height * pixelRatio;
  RRect get card => RRect.fromRectAndRadius(
    Rect.fromLTRB(56, 260, 1064, gridBottom),
    const Radius.circular(cardRadius),
  );

  Rect dayRect(int day) {
    final slot = month.leadingDays + day - 1;
    final week = weeks[slot ~/ 7];
    return Rect.fromLTWH(56 + slot % 7 * 144, week.top, 144, week.height);
  }

  Rect coverRect(int day, int index) {
    final cell = dayRect(day);
    return Rect.fromLTWH(
      cell.left + 12 + index % 2 * 64,
      cell.top + 38 + index ~/ 2 * coverRowHeight,
      48,
      72,
    );
  }
}

TextPainter exportText(
  String text,
  double size,
  double width, {
  String family = 'FolioExportSans',
  Color color = ink,
  int? maxLines,
}) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      fontFamily: family,
      fontSize: size,
      color: color,
      height: 1.2,
    ),
  ),
  textDirection: ui.TextDirection.ltr,
  maxLines: maxLines,
  ellipsis: maxLines == null ? null : '…',
)..layout(maxWidth: width);

class MonthImageRenderer implements MonthExporter {
  MonthImageRenderer(this._covers);
  final CoverSource _covers;
  final _cancellation = ExportCancellation();
  bool _busy = false;
  static Future<void>? _fonts;

  static Future<void> loadFonts() => _fonts ??= Future.wait([
    for (final font in {
      'FolioExportSans': 'assets/fonts/DMSans.ttf',
      'FolioExportLora': 'assets/fonts/Lora.ttf',
      'FolioExportIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries)
      (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load(),
  ]).then((_) {});

  @override
  Future<MonthImage> prepare(
    CalendarMonth month,
    void Function(int, int) onProgress,
  ) async {
    if (_busy) {
      throw const MonthExportException('An image is already being prepared.');
    }
    _busy = true;
    final images = <Book, ui.Image>{};
    try {
      _cancellation.check();
      final layout = MonthImageLayout(month);
      await loadFonts();
      _cancellation.check();
      var next = 0;
      var completed = 0;
      onProgress(0, month.books.length);
      await Future.wait(
        List.generate(math.min(4, month.books.length), (_) async {
          while (next < month.books.length) {
            _cancellation.check();
            final book = month.books[next++];
            ui.Image? image;
            try {
              final bytes = await _covers.load(book.coverUrl);
              _cancellation.check();
              if (bytes != null && bytes.isNotEmpty) {
                final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
                ui.ImageDescriptor? descriptor;
                try {
                  descriptor = await ui.ImageDescriptor.encoded(buffer);
                  // Reject decompression bombs before a pixel buffer is allocated.
                  if (descriptor.width * descriptor.height <= 24000000 &&
                      descriptor.width <= 12000 &&
                      descriptor.height <= 12000) {
                    final target = coverDecodeSize(
                      descriptor.width,
                      descriptor.height,
                    );
                    final codec = await descriptor.instantiateCodec(
                      targetWidth: target.width.toInt(),
                      targetHeight: target.height.toInt(),
                    );
                    try {
                      image = (await codec.getNextFrame()).image;
                    } finally {
                      codec.dispose();
                    }
                  }
                } finally {
                  descriptor?.dispose();
                  buffer.dispose();
                }
              }
            } catch (_) {
              // A title placeholder is intentional for missing or failed covers.
            }
            if (_cancellation.cancelled) {
              image?.dispose();
              _cancellation.check();
            }
            if (image != null) images[book] = image;
            onProgress(++completed, month.books.length);
          }
        }),
      );
      _cancellation.check();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..scale(MonthImageLayout.pixelRatio.toDouble());
      _paint(canvas, layout, images);
      final picture = recorder.endRecording();
      ui.Image? output;
      try {
        output = await picture.toImage(
          MonthImageLayout.physicalWidth,
          layout.physicalHeight,
        );
        _cancellation.check();
        final data = await output.toByteData(format: ui.ImageByteFormat.png);
        _cancellation.check();
        if (data == null) {
          throw const MonthExportException(
            'The image could not be encoded. Please retry.',
          );
        }
        final counts = [
          for (final event in CalendarEvent.values)
            '${event.label}: ${month.books.where((book) => CalendarEvent.of(book) == event).length}',
        ];
        return MonthImage(
          data.buffer.asUint8List(),
          MonthImageLayout.physicalWidth,
          layout.physicalHeight,
          'Folio — ${DateFormat('MMMM yyyy').format(month.month)}. ${counts.join(', ')}. '
          'One recorded date per book; not a daily reading log.',
        );
      } finally {
        output?.dispose();
        picture.dispose();
      }
    } finally {
      for (final image in images.values) {
        image.dispose();
      }
      _busy = false;
    }
  }

  static Size coverDecodeSize(int width, int height) {
    final scale = math.min(
      1.0,
      math.min(
        math.max(96 / width, 144 / height),
        512 / math.max(width, height),
      ),
    );
    return Size(
      math.max(1, (width * scale).round()).toDouble(),
      math.max(1, (height * scale).round()).toDouble(),
    );
  }

  void _paint(
    Canvas canvas,
    MonthImageLayout layout,
    Map<Book, ui.Image> images,
  ) {
    final month = layout.month;
    canvas.drawColor(paper, BlendMode.src);
    void text(
      String value,
      double x,
      double y,
      double size, {
      double width = 1008,
      String family = 'FolioExportSans',
      int? maxLines,
    }) {
      final painter = exportText(
        value,
        size,
        width,
        family: family,
        maxLines: maxLines,
      );
      painter.paint(canvas, Offset(x, y));
      painter.dispose();
    }

    void symbol(CalendarEvent event, double x, double y, {double size = 20}) {
      final painter = exportText(
        String.fromCharCode(event.icon.codePoint),
        size,
        size + 4,
        family: 'FolioExportIcons',
        color: event.color,
      );
      painter.paint(canvas, Offset(x, y));
      painter.dispose();
    }

    void cover(Book book, Rect rect) {
      final image = images[book];
      if (image == null) {
        canvas.drawRect(rect, Paint()..color = softOlive);
        canvas.drawRect(
          rect,
          Paint()
            ..color = olive
            ..style = PaintingStyle.stroke,
        );
        text(
          book.title,
          rect.left + 3,
          rect.top + 4,
          10,
          width: rect.width - 6,
          maxLines: 3,
        );
        text(
          'No cover',
          rect.left + 3,
          rect.bottom - 32,
          9,
          width: rect.width - 6,
          maxLines: 1,
        );
      } else {
        paintImage(
          canvas: canvas,
          rect: rect,
          image: image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        );
      }
    }

    text('Folio', 56, 48, 32, family: 'FolioExportLora');
    text(
      DateFormat('MMMM yyyy').format(month.month),
      56,
      100,
      48,
      family: 'FolioExportLora',
    );
    text('Your books, on their recorded dates.', 56, 168, 22);
    for (var i = 0; i < CalendarEvent.values.length; i++) {
      final event = CalendarEvent.values[i];
      symbol(event, 56 + i * 230, 217);
      text(event.label, 84 + i * 230, 214, 22, width: 192);
    }
    canvas.drawRRect(layout.card, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(layout.card);
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    for (var i = 0; i < 7; i++) {
      text(weekdays[i], 68 + i * 144, 274, 18, width: 120);
    }
    final gridPaint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var column = 1; column < 7; column++) {
      final x = 56.0 + column * 144;
      canvas.drawLine(
        Offset(x, MonthImageLayout.gridTop),
        Offset(x, layout.gridBottom),
        gridPaint,
      );
    }
    for (final week in layout.weeks) {
      canvas.drawLine(Offset(56, week.top), Offset(1064, week.top), gridPaint);
    }
    for (var day = 1; day <= month.days; day++) {
      final rect = layout.dayRect(day);
      final books = month.onDay(day);
      if (books.isNotEmpty) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(4),
            const Radius.circular(MonthImageLayout.dayRadius),
          ),
          Paint()..color = const Color(0xFFF8F9F5),
        );
      }
      text('$day', rect.left + 12, rect.top + 5, 24, width: 120);
      for (var i = 0; i < books.length; i++) {
        final coverBounds = layout.coverRect(day, i);
        cover(books[i], coverBounds);
        canvas.drawRect(
          Rect.fromLTWH(
            coverBounds.right - 20,
            coverBounds.bottom - 20,
            20,
            20,
          ),
          Paint()..color = paper,
        );
        symbol(
          CalendarEvent.of(books[i])!,
          coverBounds.right - 20,
          coverBounds.bottom - 20,
          size: 18,
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      layout.card,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (month.books.isEmpty) {
      text(
        'No recorded book dates this month. Undated books are not included.',
        56,
        layout.gridBottom + 22,
        19,
      );
    }
    text(
      'One recorded date per book · Goodreads shelf snapshot, not a daily reading log.',
      56,
      layout.height - 38.0,
      17,
    );
  }

  @override
  void dispose() {
    _cancellation.cancelled = true;
    _covers.dispose();
  }
}
