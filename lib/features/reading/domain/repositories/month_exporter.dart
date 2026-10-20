import '../entities/calendar_month.dart';
import '../entities/month_image.dart';

abstract interface class MonthExporter {
  Future<MonthImage> prepare(
    CalendarMonth month,
    void Function(int completed, int total) onProgress,
  );
  void dispose();
}
