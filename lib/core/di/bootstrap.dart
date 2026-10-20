import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app/folio_app.dart';
import '../../features/reading/data/datasources/goodreads_source.dart';
import '../../features/reading/data/datasources/reading_cache.dart';
import '../../features/reading/data/models/rss_parser.dart';
import '../../features/reading/data/repositories/cached_reading_repository.dart';
import '../../features/reading/domain/usecases/reading_library.dart';
import '../../features/reading/presentation/blocs/reading/reading_cubit.dart';
import 'month_share_dependencies.dart';

/// Composition root: owns the HTTP client and reading Cubit.
class ReadingApplication extends StatefulWidget {
  const ReadingApplication({super.key});

  @override
  State<ReadingApplication> createState() => _ReadingApplicationState();
}

class _ReadingApplicationState extends State<ReadingApplication> {
  late final http.Client _client;
  late final ReadingCubit _cubit;

  @override
  void initState() {
    super.initState();
    registerMonthSharing();
    _client = http.Client();
    _cubit = ReadingCubit(
      library: ReadingLibrary(
        repository: CachedReadingRepository(
          source: GoodreadsSource(
            client: _client,
            parser: GoodreadsRssParser(),
          ),
          cache: SharedPreferencesReadingCache(),
        ),
      ),
    );
    _cubit.load();
  }

  @override
  void dispose() {
    _cubit.close();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FolioApp(cubit: _cubit);
}
