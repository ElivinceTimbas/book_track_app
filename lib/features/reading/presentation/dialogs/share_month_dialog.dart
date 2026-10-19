import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../domain/calendar_month.dart';
import '../export/month_share_cubit.dart';

bool _previewOpen = false;

String _imageDescription(CalendarMonth month, String summary) => [
  summary,
  if (month.books.isEmpty) 'No recorded book dates this month.',
  for (final book in month.books)
    '${book.title}\n${book.author}\n'
        '${DateFormat.yMMMMd().format(book.calendarDate!)}\n'
        '${CalendarEvent.of(book)!.label}',
].join('\n');

Future<void> showShareMonth(
  BuildContext context,
  CalendarMonth snapshot,
) async {
  if (_previewOpen) return;
  _previewOpen = true;
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => ShareMonthDialog(
        create: () => GetIt.instance<MonthShareCubit>(param1: snapshot),
      ),
    );
  } finally {
    _previewOpen = false;
  }
}

class ShareMonthDialog extends StatelessWidget {
  const ShareMonthDialog({super.key, required this.create});
  final MonthShareCubit Function() create;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => create()..prepare(),
    child: const _ShareMonthContent(),
  );
}

class _ShareMonthContent extends StatelessWidget {
  const _ShareMonthContent();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MonthShareCubit>();
    return Dialog(
      backgroundColor: paper,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share ${DateFormat('MMMM yyyy').format(cubit.month.month)}',
                      style: editorial(24),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Includes book covers, titles and recorded dates. Check the preview before sharing. No account IDs, feed URLs or keys are included.',
                        style: TextStyle(fontSize: 13, color: ink),
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<MonthShareCubit, MonthShareState>(
                        buildWhen: (a, b) =>
                            a.phase != b.phase ||
                            a.image != b.image ||
                            a.completed != b.completed ||
                            a.message != b.message,
                        builder: (context, state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.phase == MonthSharePhase.preparing)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const CircularProgressIndicator(
                                        semanticsLabel: 'Preparing month image',
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Preparing image… ${state.completed}/${state.total} covers',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (state.image case final image?) ...[
                              Image.memory(
                                image.bytes,
                                fit: BoxFit.contain,
                                cacheWidth: 640,
                                semanticLabel: _imageDescription(
                                  cubit.month,
                                  image.summary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                image.summary,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (state.message case final message?)
                              Semantics(
                                liveRegion: true,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            if (state.phase == MonthSharePhase.failed)
                              OutlinedButton(
                                onPressed: cubit.prepare,
                                child: const Text('Retry image'),
                              ),
                            if (state.image != null)
                              Builder(
                                builder: (buttonContext) => FilledButton.icon(
                                  onPressed:
                                      state.phase == MonthSharePhase.sharing
                                      ? null
                                      : () {
                                          final box =
                                              buttonContext.findRenderObject()
                                                  as RenderBox?;
                                          if (box != null && box.hasSize) {
                                            cubit.share(
                                              box.localToGlobal(Offset.zero) &
                                                  box.size,
                                            );
                                          }
                                        },
                                  icon: state.phase == MonthSharePhase.sharing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.ios_share, size: 18),
                                  label: Text(
                                    state.phase == MonthSharePhase.sharing
                                        ? 'Opening share sheet…'
                                        : 'Share image',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
