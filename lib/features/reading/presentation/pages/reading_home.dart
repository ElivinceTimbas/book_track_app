import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/reading_feed.dart';
import '../blocs/reading/reading_cubit.dart';
import '../blocs/reading/reading_state.dart';
import '../widgets/dialogs/book_details_dialog.dart';
import '../widgets/dialogs/connect_feed_dialog.dart';
import '../widgets/folio_brand.dart';
import '../widgets/page_components.dart';
import 'books_page.dart';
import 'calendar_page.dart';
import 'feeds_page.dart';

/// Owns only ephemeral navigation/filter/calendar state, not data resources.
class ReadingHome extends StatefulWidget {
  const ReadingHome({super.key, required this.cubit});
  final ReadingCubit cubit;

  @override
  State<ReadingHome> createState() => _ReadingHomeState();
}

class _ReadingHomeState extends State<ReadingHome> {
  ReadingCubit get store => widget.cubit;
  late DateTime month;
  DateTime? selectedDay;
  int page = 0;
  String shelfFilter = 'All books';
  String search = '';
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
  }

  Future<void> connectFeed() async {
    if (store.busy || store.loading || store.loadFailed) return;
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConnectFeedDialog(onConnect: store.addFeed),
    );
    if (added == true && mounted) {
      final dated = store.books
          .where((book) => book.calendarDate != null)
          .toList();
      setState(() {
        if (dated.isNotEmpty) {
          final latest = dated.first.calendarDate!;
          month = DateTime(latest.year, latest.month);
        }
        selectedDay = null;
      });
      message('Your shelf is connected. Welcome to your reading calendar.');
    }
  }

  void message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
    ),
  );

  Future<void> refresh() async {
    await store.refresh();
    if (mounted) message(store.error ?? 'All shelves are up to date.');
  }

  void changeMonth(DateTime value) => setState(() {
    month = value;
    selectedDay = null;
  });

  void showBook(Book book) => showDialog<void>(
    context: context,
    builder: (_) => BookDetailsDialog(book: book),
  );

  Future<void> removeFeed(ReadingFeed feed) async {
    if (store.busy || store.loadFailed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect this shelf?', style: editorial(25)),
        content: const Text(
          'Books from this feed will be removed from Folio. You can reconnect it any time.',
          style: TextStyle(fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep shelf'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await store.removeFeed(feed);
        if (mounted) message('Shelf disconnected.');
      } catch (_) {
        if (mounted) {
          message('The shelf couldn’t be removed. Please try again.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ReadingCubit, ReadingState>(
    bloc: store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1120;
        return Scaffold(
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  backgroundColor: Colors.white,
                  indicatorColor: softOlive,
                  selectedIndex: page,
                  onDestinationSelected: (value) =>
                      setState(() => page = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_stories_outlined),
                      label: 'My books',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.rss_feed_rounded),
                      label: 'Your feeds',
                    ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desktop) sidebar(),
                Expanded(
                  child: store.loading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading saved shelves…'),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 42 : 22,
                            desktop ? 30 : 20,
                            desktop ? 42 : 22,
                            32,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1320),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  topBar(desktop),
                                  SizedBox(height: desktop ? 34 : 25),
                                  if (store.error != null) ...[
                                    ErrorBanner(store.error!),
                                    if (store.loadFailed)
                                      TextButton.icon(
                                        onPressed: store.load,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Retry loading saved shelves'),
                                      ),
                                    const SizedBox(height: 20),
                                  ],
                                  if (store.loadFailed)
                                    const EmptyState(
                                      Icons.cloud_off_outlined,
                                      'Your saved shelves are unavailable.',
                                      'Retry loading to safely restore your connections before making changes.',
                                    )
                                  else if (page == 0)
                                    CalendarPage(
                                      allBooks: store.books,
                                      month: month,
                                      selectedDay: selectedDay,
                                      hasFeeds: store.feeds.isNotEmpty,
                                      onConnect: connectFeed,
                                      onMonthChanged: changeMonth,
                                      onDaySelected: (value) =>
                                          setState(() => selectedDay = value),
                                      onBook: showBook,
                                    )
                                  else if (page == 1)
                                    BooksPage(
                                      books: store.books,
                                      hasFeeds: store.feeds.isNotEmpty,
                                      shelfFilter: shelfFilter,
                                      search: search,
                                      searchController: searchController,
                                      onSearchChanged: (value) =>
                                          setState(() => search = value),
                                      onFilterChanged: (value) =>
                                          setState(() => shelfFilter = value),
                                      onConnect: connectFeed,
                                      onBook: showBook,
                                    )
                                  else
                                    FeedsPage(
                                      feeds: store.feeds,
                                      syncing: store.busy,
                                      onRefresh: refresh,
                                      onConnect: connectFeed,
                                      onRemove: removeFeed,
                                    ),
                                  const SizedBox(height: 30),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.spa_outlined,
                                        size: 13,
                                        color: muted,
                                      ),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          'A space for your books. A little room to grow.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: muted.withValues(alpha: .85),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget sidebar() => Container(
    width: 216,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.fromLTRB(22, 37, 22, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 11), child: FolioLogo()),
        const SizedBox(height: 55),
        const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Eyebrow('YOUR LITTLE LIBRARY'),
        ),
        const SizedBox(height: 17),
        navItem(0, Icons.calendar_month_outlined, 'Calendar'),
        const SizedBox(height: 6),
        navItem(1, Icons.auto_stories_outlined, 'My books'),
        const SizedBox(height: 6),
        navItem(2, Icons.rss_feed_rounded, 'Your feeds'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote_rounded, color: rust, size: 24),
              const SizedBox(height: 8),
              Text(
                '“There is no friend as loyal as a book.”',
                style: editorial(18, height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text(
                '— Ernest Hemingway',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 22),
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: softOlive,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: olive,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your reading space',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    store.feeds.isEmpty
                        ? 'Let’s make it yours'
                        : '${store.feeds.length} connected ${store.feeds.length == 1 ? 'shelf' : 'shelves'}',
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget navItem(int index, IconData icon, String label) => Material(
    color: page == index ? softOlive : Colors.transparent,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => page = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: page == index ? olive : muted),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: page == index ? olive : muted,
                fontWeight: page == index ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (index == 2 && store.feeds.isNotEmpty) ...[
              const Spacer(),
              Text(
                '${store.feeds.length}',
                style: const TextStyle(fontSize: 11, color: olive),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget topBar(bool desktop) => Row(
    children: [
      if (!desktop)
        const FolioLogo()
      else ...[
        const Icon(Icons.wb_sunny_outlined, color: rust, size: 17),
        const SizedBox(width: 8),
        const Text(
          'A good day for a good book.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
      const Spacer(),
      if (MediaQuery.sizeOf(context).width > 500)
        Text(
          DateFormat('EEEE, MMMM d').format(DateTime.now()),
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      const SizedBox(width: 18),
      Tooltip(
        message: store.loadFailed
            ? 'Saved connections could not be loaded'
            : store.feeds.isEmpty
            ? 'No Goodreads shelves connected'
            : 'Shelves configured on this device; not a live connection status',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: store.feeds.isEmpty ? const Color(0xFFF2EDE3) : softOlive,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                store.feeds.isEmpty
                    ? Icons.rss_feed_rounded
                    : Icons.check_circle_outline,
                size: 12,
                color: store.feeds.isEmpty ? rust : olive,
              ),
              const SizedBox(width: 5),
              Text(
                store.loadFailed
                    ? 'Load failed'
                    : store.feeds.isEmpty
                    ? 'Not connected'
                    : 'Connected',
                style: TextStyle(
                  fontSize: 10,
                  color: store.feeds.isEmpty ? rust : olive,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
