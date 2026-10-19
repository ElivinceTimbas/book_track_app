import 'dart:typed_data';

import 'calendar_month.dart';

class MonthExportException implements Exception {
  const MonthExportException(this.message);
  final String message;
}

class ExportCancellation {
  bool cancelled = false;
  void check() {
    if (cancelled) throw const MonthExportException('Export cancelled.');
  }
}

abstract interface class CoverSource {
  Future<Uint8List?> load(String url);
  void dispose();
}

class MonthImage {
  const MonthImage(this.bytes, this.width, this.height, this.summary);
  final Uint8List bytes;
  final int width;
  final int height;
  final String summary;
}

abstract interface class MonthExporter {
  Future<MonthImage> prepare(
    CalendarMonth month,
    void Function(int completed, int total) onProgress,
  );
  void dispose();
}
