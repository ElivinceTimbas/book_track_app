import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../domain/goodreads_connection.dart';
import '../../domain/reading_feed.dart';
import '../widgets/folio_brand.dart';
import '../widgets/page_components.dart';

class FeedsPage extends StatelessWidget {
  const FeedsPage({
    super.key,
    required this.feeds,
    required this.syncing,
    required this.onRefresh,
    required this.onConnect,
    required this.onRemove,
  });
  final List<ReadingFeed> feeds;
  final bool syncing;
  final VoidCallback onRefresh;
  final VoidCallback onConnect;
  final ValueChanged<ReadingFeed> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        'A connection to your shelves.',
        'Your public Goodreads feeds, all in one place.',
      ),
      const SizedBox(height: 26),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('CONNECTED FEEDS')),
                if (feeds.isNotEmpty)
                  IconButton(
                    tooltip: 'Refresh all feeds',
                    onPressed: syncing ? null : onRefresh,
                    icon: syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (feeds.isEmpty) ...[
              Text('Your next chapter starts here.', style: editorial(25)),
              const SizedBox(height: 10),
              const Text(
                'Connect with your Goodreads user ID and shelf. No password needed.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
              const SizedBox(height: 20),
            ],
            for (final feed in feeds) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.rss_feed_rounded, color: olive, size: 21),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feed.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${feed.books.length} books · Synced ${DateFormat('MMM d, h:mm a').format(feed.syncedAt)}',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          goodreadsConnectionLabel(feed.url),
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove feed',
                    onPressed: syncing ? null : () => onRemove(feed),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              const Divider(height: 1),
              const SizedBox(height: 17),
            ],
            FilledButton.icon(
              onPressed: syncing ? null : onConnect,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Add Goodreads feed'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: softOlive,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('A NOTE ABOUT YOUR CALENDAR'),
            SizedBox(height: 13),
            Text(
              'Your calendar uses Goodreads’ finished and started dates. If a book has neither, it appears on the date it was added to a shelf. Books without dates stay in My books.',
              style: TextStyle(color: olive, fontSize: 12, height: 1.9),
            ),
            SizedBox(height: 10),
            Text(
              'Folio is read-only: it cannot edit shelves or log reading progress. RSS may include only recent entries, not your full history. Refresh replaces each successful shelf snapshot; cached books remain available if a refresh fails.',
              style: TextStyle(color: olive, fontSize: 12, height: 1.9),
            ),
          ],
        ),
      ),
    ],
  );
}
