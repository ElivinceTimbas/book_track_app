enum ReadingStatus { finished, reading, toRead }

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.status,
    this.coverUrl = '',
    this.pages = 0,
    this.rating = 0,
    this.readAt,
    this.startedAt,
    this.addedAt,
  });

  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final ReadingStatus status;
  final int pages;
  final int rating;
  final DateTime? readAt;
  final DateTime? startedAt;
  final DateTime? addedAt;

  DateTime? get calendarDate => readAt ?? startedAt ?? addedAt;
}
