import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class FolioLogo extends StatelessWidget {
  const FolioLogo({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.auto_stories_rounded, color: olive, size: 26),
      const SizedBox(width: 10),
      Text('folio', style: editorial(33, weight: FontWeight.w600)),
      Text(
        '.',
        style: editorial(34, color: rust, weight: FontWeight.w600),
      ),
    ],
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 8,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.35,
      color: muted,
    ),
  );
}
