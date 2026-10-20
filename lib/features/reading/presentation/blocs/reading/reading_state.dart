import 'package:equatable/equatable.dart';

import '../../../domain/entities/book.dart';
import '../../../domain/entities/reading_feed.dart';
import '../../../domain/usecases/reading_rules.dart';

class ReadingState extends Equatable {
  ReadingState({
    List<ReadingFeed> feeds = const [],
    this.loading = true,
    this.loaded = false,
    this.mutations = 0,
    this.syncing = false,
    this.error,
  }) : feeds = List.unmodifiable(feeds);

  final List<ReadingFeed> feeds;
  final bool loading;
  final bool loaded;
  final int mutations;
  final bool syncing;
  final String? error;

  List<Book> get books => mergeBooks(feeds);
  bool get busy => mutations > 0;
  bool get loadFailed => !loading && !loaded;

  @override
  List<Object?> get props => [
    feeds,
    loading,
    loaded,
    mutations,
    syncing,
    error,
  ];
}
