import '../entities/reading_feed.dart';

/// The data boundary used by the library. Implementations own their resources;
/// the composition root (not a borrowing controller) is responsible for disposal.
abstract interface class ReadingRepository {
  Future<List<ReadingFeed>> load();
  Future<void> save(List<ReadingFeed> feeds);
  String normalizeUrl(String input);
  Future<ReadingFeed> fetch(String url);
}
