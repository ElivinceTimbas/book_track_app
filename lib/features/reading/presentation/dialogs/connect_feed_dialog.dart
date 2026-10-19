import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/feed_exception.dart';
import '../../domain/goodreads_connection.dart';

class ConnectFeedDialog extends StatefulWidget {
  const ConnectFeedDialog({super.key, required this.onConnect});
  final Future<void> Function(String url) onConnect;

  @override
  State<ConnectFeedDialog> createState() => _ConnectFeedDialogState();
}

class _ConnectFeedDialogState extends State<ConnectFeedDialog> {
  final form = GlobalKey<FormState>();
  final userId = TextEditingController();
  final customShelf = TextEditingController();
  final originalUrl = TextEditingController();
  String shelf = 'read';
  bool advanced = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    userId.dispose();
    customShelf.dispose();
    originalUrl.dispose();
    super.dispose();
  }

  String? validate(void Function() action) {
    try {
      action();
      return null;
    } on FeedException catch (exception) {
      return exception.message;
    }
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    final url = advanced
        ? normalizeGoodreadsUrl(originalUrl.text)
        : goodreadsShelfUrl(
            userId: userId.text,
            shelf: shelf == 'custom' ? customShelf.text : shelf,
          );
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onConnect(url.toString());
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(() {
          busy = false;
          error = exception is FeedException
              ? exception.message
              : 'We couldn’t save this feed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 490),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rss_feed_rounded, color: olive, size: 32),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Bring your books along.', style: editorial(29)),
                const SizedBox(height: 10),
                const Text(
                  'Connect a public Goodreads shelf. Read-only: no login, password or API key needed. RSS may include only recent books, not your complete history.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.8),
                ),
                const SizedBox(height: 22),
                if (!advanced) ...[
                  TextFormField(
                    key: const ValueKey('goodreads-user-id'),
                    controller: userId,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Goodreads user ID',
                      helperText: 'The number in your Goodreads profile URL',
                      helperMaxLines: 2,
                      errorMaxLines: 3,
                    ),
                    validator: (value) => validate(() {
                      goodreadsShelfUrl(userId: value ?? '', shelf: 'read');
                    }),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: shelf,
                    decoration: const InputDecoration(labelText: 'Shelf'),
                    items: const [
                      DropdownMenuItem(value: 'read', child: Text('Read')),
                      DropdownMenuItem(
                        value: 'currently-reading',
                        child: Text('Currently reading'),
                      ),
                      DropdownMenuItem(
                        value: 'to-read',
                        child: Text('Want to read'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Custom shelf'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => shelf = value!),
                  ),
                  if (shelf == 'custom') ...[
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('goodreads-custom-shelf'),
                      controller: customShelf,
                      enabled: !busy,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Custom shelf slug',
                        hintText: 'e.g. favorite-books',
                        errorMaxLines: 3,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a custom shelf slug.'
                          : null,
                      onFieldSubmitted: (_) => submit(),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Copy the original RSS link from the bottom of your Goodreads shelf page. Additional URL parameters will be kept. Treat any included key as private.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.7),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    key: const ValueKey('goodreads-original-url'),
                    controller: originalUrl,
                    enabled: !busy,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Goodreads RSS feed URL',
                      errorMaxLines: 4,
                    ),
                    validator: (value) => validate(() {
                      normalizeGoodreadsUrl(value ?? '');
                    }),
                    onFieldSubmitted: (_) => submit(),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          advanced = !advanced;
                          error = null;
                        }),
                  child: Text(
                    advanced
                        ? 'Use user ID and shelf instead'
                        : 'Use an original RSS link instead',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      style: const TextStyle(color: rust, fontSize: 12, height: 1.6),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Connecting your shelf…'),
                            ],
                          )
                        : const Text('Connect my shelf'),
                  ),
                ),
                const SizedBox(height: 13),
                const Text(
                  'Add more shelves anytime in Your feeds.',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
