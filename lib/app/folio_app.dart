import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/reading/presentation/blocs/reading/reading_cubit.dart';
import '../features/reading/presentation/pages/reading_home.dart';

class FolioApp extends StatelessWidget {
  const FolioApp({super.key, required this.cubit});
  final ReadingCubit cubit;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Folio — A little reading, every day',
    debugShowCheckedModeBanner: false,
    theme: folioTheme(),
    home: ReadingHome(cubit: cubit),
  );
}
