import 'package:get_it/get_it.dart';

import '../../features/reading/data/datasources/export_cover_source.dart';
import '../../features/reading/data/repositories/share_plus_image_sharer.dart';
import '../../features/reading/domain/entities/calendar_month.dart';
import '../../features/reading/domain/repositories/image_sharer.dart';
import '../../features/reading/domain/repositories/month_exporter.dart';
import '../../features/reading/presentation/blocs/month_share/month_share_cubit.dart';
import '../../features/reading/presentation/widgets/export/month_image_renderer.dart';

void registerMonthSharing() {
  final di = GetIt.instance;
  if (di.isRegistered<MonthExporter>()) return;
  di.registerFactory<MonthExporter>(
    () => MonthImageRenderer(ExportCoverSource()),
  );
  di.registerLazySingleton<ImageSharer>(() => SharePlusImageSharer());
  di.registerFactoryParam<MonthShareCubit, CalendarMonth, void>(
    (month, _) =>
        MonthShareCubit(month, di<MonthExporter>(), di<ImageSharer>()),
  );
}
