import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/calendar_month.dart';

extension CalendarEventVisuals on CalendarEvent {
  IconData get icon => switch (this) {
    CalendarEvent.finished => Icons.check_circle_outline_rounded,
    CalendarEvent.started => Icons.play_circle_outline_rounded,
    CalendarEvent.shelfDate => Icons.bookmark_border_rounded,
  };

  Color get color => switch (this) {
    CalendarEvent.finished => olive,
    CalendarEvent.started => const Color(0xFF925233),
    CalendarEvent.shelfDate => ink,
  };
}

class CalendarEventBadge extends StatelessWidget {
  const CalendarEventBadge(
    this.event, {
    super.key,
    this.count,
    this.label = true,
  });
  final CalendarEvent event;
  final int? count;
  final bool label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${event.label}${count == null ? '' : ': $count'}',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(event.icon, size: 18, color: event.color),
        if (label || count != null) ...[
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${label ? event.label : ''}${label && count != null ? ' ' : ''}${count ?? ''}',
              style: const TextStyle(fontSize: 13, color: ink),
            ),
          ),
        ],
      ],
    ),
  );
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 17,
    runSpacing: 10,
    children: [
      CalendarEventBadge(CalendarEvent.finished),
      CalendarEventBadge(CalendarEvent.started),
      CalendarEventBadge(CalendarEvent.shelfDate),
    ],
  );
}
