import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../features/reading/data/cached_reading_repository.dart';
import '../features/reading/data/goodreads_source.dart';
import '../features/reading/data/reading_cache.dart';
import '../features/reading/data/rss_parser.dart';
import '../features/reading/presentation/reading_controller.dart';
import 'folio_app.dart';

/// Composition root: owns the HTTP client and presentation controller.
class ReadingApplication extends StatefulWidget {
  const ReadingApplication({super.key});

  @override
  State<ReadingApplication> createState() => _ReadingApplicationState();
}

class _ReadingApplicationState extends State<ReadingApplication> {
  late final http.Client _client;
  late final ReadingController _controller;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _controller = ReadingController(
      repository: CachedReadingRepository(
        source: GoodreadsSource(client: _client, parser: GoodreadsRssParser()),
        cache: SharedPreferencesReadingCache(),
      ),
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FolioApp(controller: _controller);
}
