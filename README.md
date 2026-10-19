# Folio

A warm, quiet, read-only Goodreads RSS viewer built with Flutter. Connect public shelves to browse their current feed snapshots by date. Folio starts empty and never supplies sample books.

## Run

```sh
flutter pub get
flutter run -d macos
```

Android and iOS project targets are also included. Choose an emulator, simulator, or connected device with `flutter devices`, then use `flutter run -d <device-id>`.

## Connect your shelves

1. In Folio, choose **Connect Goodreads**.
2. Enter your **Goodreads user ID**: the positive numeric part of your Goodreads profile URL (`/user/show/123456-name` → `123456`).
3. Choose **Read** (the default), **Currently reading**, **Want to read**, or **Custom shelf** and enter that shelf’s slug.
4. Choose **Connect my shelf**. Folio builds the HTTPS RSS URL, fetches the shelf, and saves it locally before confirming success.
5. Add additional shelves and refresh or disconnect them under **Your feeds**. Disconnecting the final shelf leaves an empty library.

The profile and shelves must be public. No Goodreads login, password, or API key is requested. The generated URL looks like `https://www.goodreads.com/review/list_rss/123456?shelf=read`.

If your feed requires extra URL parameters, choose **Use an original RSS link instead** and paste the RSS link from the bottom of your Goodreads shelf page. This alternative retains all query parameters, including repeated parameters and optional keys. Only the active form is validated. Connection errors keep your input available for retry.

Equivalent connections for the same user ID and shelf are rejected, even if host spelling, trailing slash, query order, or optional request parameters differ. The existing connection’s request URL is preserved. To replace a connection with a different original link, disconnect it and reconnect. Your feeds displays only the user ID and shelf, never the complete request URL. Original links may contain private keys: they are stored locally with the cached feed, not in an encrypted credential vault; do not share them.

## Features

- Monthly calendar with day selection, month navigation, and a Today shortcut.
- Monthly finished-book and total book-page counts, current reads, and dated shelf entries.
- Searchable library with reading-status filters and book details.
- Multiple RSS feeds, duplicate-book handling, manual refresh, and local offline caching.
- Genuine empty, loading, connected-empty and persistent error states, with safe cache-load retry.
- Responsive desktop and mobile layouts.

Calendar dates use `user_read_at`, then `user_started_at`, then `user_date_added` (or `pubDate`). Entries without a date remain in the library. An added date is explicitly labeled **Added to shelf**, never presented as a completion date. Impossible dates are rejected. The calendar is not a daily reading log, and book-page totals are not measured reading progress.

Goodreads can limit RSS to recent shelf entries. Folio cannot guarantee a complete history, import missing history, edit books or shelves, or write reading progress back to Goodreads. Each successful refresh replaces that shelf’s cached snapshot; it does not accumulate historical entries. Failed refreshes keep the previous cached books. **Connected** means shelves are configured locally, not that the service is live or the cache is fresh; each feed shows its last successful sync time.

Feeds and their cached books are stored locally using SharedPreferences, with the existing v1 cache schema retained. If cache loading fails, Folio blocks connection changes until loading is successfully retried so unread saved data cannot be silently overwritten. Book covers load from the feed, with illustrated fallback covers if unavailable.

Lora and DM Sans fonts are bundled for consistent offline typography. Their SIL Open Font Licenses are included in `assets/fonts/`.

## Verify

```sh
flutter analyze
flutter test
```

## Architecture

The app uses a single reading feature with constructor injection and the existing
`ChangeNotifier` / `ListenableBuilder` state management. There is no service
locator, dependency-injection framework, or extra use-case/DTO layer.

```text
lib/
  main.dart                         # Flutter entry point
  app/
    bootstrap.dart                  # Composition and resource ownership
    folio_app.dart                   # MaterialApp
    theme.dart                       # Original palette, fonts and theme
  features/reading/
    domain/                         # Plain Dart entities, rules, source contract
    data/                           # Goodreads HTTP, RSS, JSON and local cache
    presentation/                   # Controller, labels and responsive UI
      pages/                        # Calendar, library and connected feeds
      dialogs/                      # Connect shelf and book details
      widgets/                      # Shared visual components
```

Dependencies point inward: **presentation → domain ← data**. Domain has no
Flutter, HTTP, XML, preferences, data, or presentation imports. Presentation
depends on `ReadingRepository`, never on a concrete cache or network adapter.
The composition root is the only place wiring data and presentation together.
The shared app theme is visual configuration, not a data dependency.

- `Book` and `ReadingFeed` are immutable; feed books and controller collections
  are defensive, unmodifiable snapshots. `mergeBooks` owns ID deduplication and
  descending calendar-date sorting. Calendar date precedence remains finished,
  started, then added. An undated book stays in the library.
- Deduplication intentionally replaces an existing book when a candidate has a
  higher-priority status **or** the existing book is undated and the candidate is
  dated. Otherwise the first feed wins; a later date alone does not win.
- Domain connection helpers build and validate URLs, identify equivalent shelves,
  and provide safe display labels without additional stored metadata.
- `GoodreadsSource` canonicalizes request URLs and handles HTTP errors and the
  25-second timeout. `GoodreadsRssParser` independently interprets RSS, preserving
  Goodreads' recorded day rather than shifting dates across time zones.
- `SharedPreferencesReadingCache` and `feed_json.dart` own persistence. The
  `folio.feeds.v1` key, JSON fields, enum names and ISO date encoding remain
  compatible with existing installs. A cache read never triggers a network call.
- `ReadingController` loads cached shelves and derives books only from actual
  feeds. Load/add/remove/refresh share a serialized queue; a failed operation
  does not poison subsequent work. Add/remove/refresh publish feeds only after
  a successful save, and mutations require a successful cache load. Refresh
  fetches sequentially, retaining cached
  feeds for individual network failures and preserving all old state if the
  final save fails. Navigation, visible search text (with a clear action), filters
  and selected dates stay in UI. Errors persist across page navigation.
- `ReadingApplication` owns/disposes the controller and HTTP client. The
  controller borrows its repository; the network adapter borrows its client.
  Disposed controllers ignore late completions, stop further refresh requests,
  and do not notify listeners or publish new state. Already-issued cache writes
  can finish; disposal is not cancellation or rollback of persistence.

Tests cover pure domain rules, literal legacy JSON, cache/repository separation,
URL construction/validation/query encoding, request/error/timeout behavior,
RSS interpretation, fake-repository connection dialogs, serialized mutation
races/failures, load-retry protection, controller lifecycle, search navigation,
and responsive UI flows at 320, 390 and 1400 pixels. Sample factories live only
under `test/support/`; tests do not verify a real Goodreads account or live RSS
availability. Tests use package imports across the `test`/`lib` boundary and
relative imports within each source tree, following the Flutter lints.
