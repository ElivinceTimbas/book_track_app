import '../errors/month_export_exception.dart';

class ExportCancellation {
  bool cancelled = false;
  void check() {
    if (cancelled) throw const MonthExportException('Export cancelled.');
  }
}
