import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

import '../features/reading/data/export_cover_source.dart';
import '../features/reading/domain/calendar_month.dart';
import '../features/reading/domain/month_export.dart';
import '../features/reading/presentation/export/month_image_renderer.dart';
import '../features/reading/presentation/export/month_share_cubit.dart';

void registerMonthSharing() {
  final di = GetIt.instance;
  if (di.isRegistered<MonthExporter>()) return;
  di.registerFactory<MonthExporter>(
    () => MonthImageRenderer(ExportCoverSource()),
  );
  di.registerLazySingleton<ShareImage>(() => SharePlus.instance.share);
  di.registerFactoryParam<MonthShareCubit, CalendarMonth, void>(
    (month, _) => MonthShareCubit(month, di<MonthExporter>(), di<ShareImage>()),
  );
}
