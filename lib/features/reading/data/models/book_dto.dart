import '../../domain/entities/book.dart';

class BookDto {
  const BookDto({
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
  final String status;
  final String coverUrl;
  final int pages;
  final int rating;
  final String? readAt;
  final String? startedAt;
  final String? addedAt;

  factory BookDto.fromJson(Map<String, dynamic> json) => BookDto(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    status: json['status'] as String,
    coverUrl: json['coverUrl'] as String? ?? '',
    pages: json['pages'] as int? ?? 0,
    rating: json['rating'] as int? ?? 0,
    readAt: json['readAt'] as String?,
    startedAt: json['startedAt'] as String?,
    addedAt: json['addedAt'] as String?,
  );

  factory BookDto.fromEntity(Book book) => BookDto(
    id: book.id,
    title: book.title,
    author: book.author,
    status: book.status.name,
    coverUrl: book.coverUrl,
    pages: book.pages,
    rating: book.rating,
    readAt: book.readAt?.toIso8601String(),
    startedAt: book.startedAt?.toIso8601String(),
    addedAt: book.addedAt?.toIso8601String(),
  );

  Book toEntity() => Book(
    id: id,
    title: title,
    author: author,
    status: ReadingStatus.values.byName(status),
    coverUrl: coverUrl,
    pages: pages,
    rating: rating,
    readAt: DateTime.tryParse(readAt ?? ''),
    startedAt: DateTime.tryParse(startedAt ?? ''),
    addedAt: DateTime.tryParse(addedAt ?? ''),
  );

  // Preserve the v1 cache keys, enum names and ISO date encoding.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'status': status,
    'pages': pages,
    'rating': rating,
    'readAt': readAt,
    'startedAt': startedAt,
    'addedAt': addedAt,
  };
}
