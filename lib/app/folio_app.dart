import 'package:flutter/material.dart';

import '../features/reading/presentation/reading_controller.dart';
import '../features/reading/presentation/reading_home.dart';
import 'theme.dart';

class FolioApp extends StatelessWidget {
  const FolioApp({super.key, required this.controller});
  final ReadingController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Folio — A little reading, every day',
    debugShowCheckedModeBanner: false,
    theme: folioTheme(),
    home: ReadingHome(controller: controller),
  );
}
