import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/book.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_metadata.dart';
import '../widgets/page_components.dart';

class BooksPage extends StatelessWidget {
  const BooksPage({
    super.key,
    required this.books,
    required this.hasFeeds,
    required this.shelfFilter,
    required this.search,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onConnect,
    required this.onBook,
  });

  final List<Book> books;
  final bool hasFeeds;
  final String shelfFilter;
  final String search;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onConnect;
  final ValueChanged<Book> onBook;

  @override
  Widget build(BuildContext context) {
    final filtered = books.where((book) {
      final matchesShelf =
          shelfFilter == 'All books' ||
          (shelfFilter == 'Finished' &&
              book.status == ReadingStatus.finished) ||
          (shelfFilter == 'Reading' && book.status == ReadingStatus.reading) ||
          (shelfFilter == 'Want to read' &&
              book.status == ReadingStatus.toRead);
      return matchesShelf &&
          '${book.title} ${book.author}'.toLowerCase().contains(
            search.toLowerCase(),
          );
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Good company, on every shelf.',
          'All your books, gathered in one quiet corner.',
        ),
        const SizedBox(height: 25),
        if (!hasFeeds) ...[
          ConnectBanner(onConnect: onConnect),
          const SizedBox(height: 25),
        ],
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Find a title or author',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            hintStyle: const TextStyle(fontSize: 13, color: muted),
            suffixIcon: search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in [
              'All books',
              'Finished',
              'Reading',
              'Want to read',
            ])
              ChoiceChip(
                label: Text(filter, style: const TextStyle(fontSize: 11)),
                selected: shelfFilter == filter,
                onSelected: (_) => onFilterChanged(filter),
                selectedColor: softOlive,
                backgroundColor: Colors.white,
                side: const BorderSide(color: line),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 22),
        if (filtered.isEmpty)
          EmptyState(
            Icons.auto_stories_outlined,
            books.isEmpty
                ? hasFeeds
                      ? 'No books in your connected shelves yet.'
                      : 'Your library is empty.'
                : 'No matching books.',
            books.isEmpty
                ? 'Connect a shelf with books or refresh to check for updates. RSS can return a limited snapshot.'
                : 'Try another title, author or shelf filter.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 175).floor().clamp(2, 6);
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 23,
                children: [
                  for (final book in filtered)
                    SizedBox(
                      width: width,
                      child: InkWell(
                        onTap: () => onBook(book),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: BookCover(
                                  book: book,
                                  width: width.clamp(80, 120).toDouble() - 10,
                                  height: 158,
                                  radius: 4,
                                ),
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                height: 44,
                                child: Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: editorial(16, height: 1.35),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              StatusBadge(book),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
