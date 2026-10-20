import 'package:book_track_app/features/reading/domain/entities/book.dart';
import 'package:book_track_app/features/reading/domain/entities/reading_feed.dart';
import 'package:book_track_app/features/reading/domain/repositories/reading_repository.dart';

Book sampleBook({
  String id = 'book',
  String title = 'A book',
  ReadingStatus status = ReadingStatus.toRead,
  DateTime? readAt,
  DateTime? startedAt,
  DateTime? addedAt,
}) => Book(
  id: id,
  title: title,
  author: 'An author',
  status: status,
  readAt: readAt,
  startedAt: startedAt,
  addedAt: addedAt,
);

ReadingFeed sampleFeed({
  String url = 'feed-a',
  List<Book> books = const [],
  String name = 'A shelf',
}) => ReadingFeed(
  url: url,
  name: name,
  books: books,
  syncedAt: DateTime(2025, 5, 7, 12),
);

class FakeReadingRepository implements ReadingRepository {
  List<ReadingFeed> stored = [];
  final fetched = <String>[];
  final normalized = <String>[];
  final saves = <List<ReadingFeed>>[];
  Future<List<ReadingFeed>> Function()? onLoad;
  Future<ReadingFeed> Function(String)? onFetch;
  Future<void> Function(List<ReadingFeed>)? onSave;
  String Function(String) normalize = (input) => input.trim();

  @override
  Future<List<ReadingFeed>> load() async =>
      onLoad == null ? stored : await onLoad!();

  @override
  String normalizeUrl(String input) {
    normalized.add(input);
    return normalize(input);
  }

  @override
  Future<ReadingFeed> fetch(String url) async {
    fetched.add(url);
    return onFetch == null ? sampleFeed(url: url) : await onFetch!(url);
  }

  @override
  Future<void> save(List<ReadingFeed> feeds) async {
    saves.add(feeds);
    await onSave?.call(feeds);
    stored = List.of(feeds);
  }
}
