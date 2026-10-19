import 'reading_feed.dart';

/// The source boundary used by presentation. Implementations own their resources;
/// the composition root (not a borrowing controller) is responsible for disposal.
abstract interface class ReadingRepository {
  Future<List<ReadingFeed>> load();
  Future<void> save(List<ReadingFeed> feeds);
  String normalizeUrl(String input);
  Future<ReadingFeed> fetch(String url);
}
