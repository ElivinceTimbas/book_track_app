import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: editorial(MediaQuery.sizeOf(context).width < 600 ? 30 : 37),
      ),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: muted, height: 1.6),
      ),
    ],
  );
}

class ConnectBanner extends StatelessWidget {
  const ConnectBanner({super.key, required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(23),
    decoration: BoxDecoration(
      color: const Color(0xFFECEFDF),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE0E5D4)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final text = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.rss_feed_rounded, color: olive, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your books belong here.', style: editorial(22)),
                  const SizedBox(height: 7),
                  const Text(
                    'Connect your public Goodreads RSS feeds and bring your reading life together.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF727B65),
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final button = FilledButton.icon(
          onPressed: onConnect,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Connect Goodreads'),
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 18), button],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 20),
                  button,
                ],
              );
      },
    ),
  );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFAEEE6),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 17, color: rust),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.6, color: rust),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.title, this.subtitle, {super.key});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: line),
    ),
    child: Column(
      children: [
        Icon(icon, color: olive, size: 28),
        const SizedBox(height: 15),
        Text(title, style: editorial(22), textAlign: TextAlign.center),
        const SizedBox(height: 9),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: muted, height: 1.7),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
