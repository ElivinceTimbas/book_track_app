import '../../domain/entities/book.dart';

extension BookLabels on Book {
  String get eventLabel => readAt != null
      ? 'Finished reading'
      : startedAt != null
      ? 'Started reading'
      : 'Added to shelf';
}
