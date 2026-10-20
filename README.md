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
- Accessible calendar event symbols and counts: **Finished** (check-circle), **Started** (play-circle), and **Shelf date** (bookmark outline). The legend, day markers, activity and exported images use the same mapping, never color alone.
- **Share month** previews and shares a high-resolution, calendar-only PNG of the viewed month, with every book cover on its recorded date.
- Monthly finished-book and total book-page counts, current reads, and dated shelf entries.
- Searchable library with reading-status filters and book details.
- Multiple RSS feeds, duplicate-book handling, manual refresh, and local offline caching.
- Genuine empty, loading, connected-empty and persistent error states, with safe cache-load retry.
- Responsive desktop and mobile layouts.

Calendar rows reserve space only for the event categories actually present in the month. At large text sizes or unusually large day counts, the weekday header and grid scroll sideways together rather than shrinking text or wrapping the digits of a count; an inline hint explains this.

Calendar dates use `user_read_at`, then `user_started_at`, then `user_date_added` (or `pubDate`). Entries without a date remain in the library. The calendar labels an added date **Shelf date**, never a completion date. Details describe it as **Added to shelf**. Impossible dates are rejected. The calendar is not a daily reading log, and book-page totals are not measured reading progress.

### Share a calendar month

Navigate to any month and choose **Share month**, then review **Share MONTH YEAR** and choose **Share image**. The preview snapshots the entire viewed month from the deduplicated library when opened: selecting a day, searching/filtering the library, refreshing feeds, or changing the underlying month cannot change that open preview. Close and reopen to capture new data. Empty actual months can also be shared.

The preview has no visible book list. Its image semantics retain every included book’s full Unicode title, author, recorded date and exact event label from the immutable snapshot, without connection metadata. A concise month summary and privacy notice remain visible; the dialog scrolls at larger text sizes so **Share image** remains reachable. These accessibility labels belong to the in-app preview, not embedded PNG metadata.

The opaque Folio-paper PNG includes branding, month/year, a rounded white calendar card with a single border, Monday-first dates with blank adjacent-month cells, actual covers, individual event badges and the matching legend. All books appear **exactly once** in their date cells, in two columns; each week grows to contain its busiest day, without a four-cover cap, per-day tally strips, overflow notices or a title appendix. Populated days have subtly rounded surfaces. Each book uses only its one actual recorded date; there are no invented reading ranges. Missing, corrupt, oversized or unavailable covers use a **No cover** title placeholder, not fabricated artwork. Placeholder titles may be abbreviated visually; full titles remain available through the preview’s screen-reader label. A compact provenance footer (and a genuine empty-month message when appropriate) follows the calendar. The interactive Calendar page’s legends, tallies and activity are unchanged. Cover loading/decoding completes before sharing.

Exports are named `folio-YYYY-MM.png` and shared as `image/png` with a short accessible count summary. The original high-resolution PNG bytes are shared, not the independently downsampled preview. They include **book covers, placeholder titles and recorded dates**, but no account IDs, feed URLs, keys, navigation or selection state. Check the preview for personal information in book titles before sharing. Cancelling the preview cancels cover requests; dismissing a native share sheet does not claim success. Some share targets accept only the image and omit accompanying text. Choosing a share action is not proof of delivery.

Image quality and safety: the 1120-logical-pixel layout is painted on a true **2× canvas, producing a 2240px-wide PNG** with twice the logical height and crisp rasterized text. Logical margins are 56px and columns 144px; week height is `50 + 82 × max(1, ceil(busiest-day books / 2))`. The card radius is 30 logical pixels (similar in proportion to the app’s 13px card), with 8px day corners. Before any cover request or output allocation, exports enforce **100 books, 8192 physical pixels per axis and 12 megapixels total** (at most about 46 MiB per RGBA output buffer). A normal six-week month with up to four books per day is about 7.5 megapixels and fits reliably. Concentrated busy days may exceed the image budget even below 100 books: the error states **“This month has too many books for one image. No image was created and no books were omitted.”** There is no silent downscaling, clipping, or request to disconnect shelves. There is no appendix-based height or title-length limit.

Cover requests have four workers, a 12-second total deadline per cover, 8-second connect/receive limits, three redirects and a 3 MiB compressed-byte limit each. Image descriptors larger than 24 megapixels or 12000px on either axis are rejected before pixel decoding. Covers decode for their 96×144 physical destination using crop-aware sizing, never upscale a small source, and cap the longest decoded edge at 512px to bound unusual aspect ratios. High-quality filtering is used when painting. Buffers, descriptors, codecs, decoded covers, pictures and output images are disposed. PNG encoding, native sharing and the 640px-wide preview can need additional transient memory; the 12MP output budget is deliberately conservative, not an unlimited-export guarantee.

Native sharing uses `share_plus 13.3.1`: Flutter ≥3.38.1, Dart ≥3.10, iOS ≥13, macOS ≥10.15, Java 17, Kotlin ≥2.2, AGP ≥8.12.1 and Gradle ≥8.13. The checked-in targets meet these version requirements. **Adding/updating this native plugin requires a full rebuild**, not hot reload: stop the app, run `flutter pub get`, then `flutter run -d <device-id>` (or `flutter run -d macos`). The share popover anchors to the actual Share image button bounds on iPad/macOS. The plugin creates a temporary cached file for `XFile.fromData`; it is not a permanent photo-library save. The OS manages these temporary files; export PNGs may remain in the app cache after sharing. No photo-library permission is required.

Goodreads can limit RSS to recent shelf entries. Folio cannot guarantee a complete history, import missing history, edit books or shelves, or write reading progress back to Goodreads. Each successful refresh replaces that shelf’s cached snapshot; it does not accumulate historical entries. Failed refreshes keep the previous cached books. **Connected** means shelves are configured locally, not that the service is live or the cache is fresh; each feed shows its last successful sync time.

Feeds and their cached books are stored locally using SharedPreferences, with the existing v1 cache schema retained. If cache loading fails, Folio blocks connection changes until loading is successfully retried so unread saved data cannot be silently overwritten. Book covers load from the feed, with illustrated fallback covers if unavailable.

Lora and DM Sans fonts are bundled for consistent offline typography. Their SIL Open Font Licenses are included in `assets/fonts/`.

## Verify

```sh
flutter analyze
flutter test
```

## Architecture

The app is organized by feature, with responsibilities separated inside each
clean architecture layer. `ReadingLibrary` in `domain/usecases` owns shelf
operations, the serialized queue and immutable saved snapshots. `ReadingCubit`
and `MonthShareCubit` in `presentation/blocs` expose immutable Equatable states;
pages observe them through `BlocBuilder`. Constructors receive their dependencies,
and `core/di` owns concrete wiring and resource lifetimes.

```text
lib/
  main.dart
  app/
    folio_app.dart                   # MaterialApp
  core/
    di/                             # Bootstrap and dependency registrations
    errors/                         # Exceptions shared across layers
    theme/                          # Palette, fonts and app theme
    utils/                          # Export cancellation
  features/reading/
    presentation/
      pages/                        # Reading home, calendar, books and feeds
      widgets/                      # Reusable UI, dialogs and export painting
      blocs/
        reading/                    # ReadingCubit and ReadingState
        month_share/                # MonthShareCubit and MonthShareState
    domain/
      entities/                     # Books, feeds, calendar and image values
      repositories/                 # Reading, export, cover and sharing contracts
      usecases/                     # Shelf operations, connection rules and merging
    data/
      repositories/                 # Implementations of domain contracts
      datasources/                  # Goodreads HTTP, local cache and cover loading
      models/                       # Book/feed DTOs and RSS deserialization
```

Dependencies point inward: **presentation → domain ← data**. Domain has no
Flutter, HTTP, XML, preferences, data, or presentation imports. Presentation
depends on the domain library and export/share contracts, never on concrete
cache, network or native sharing adapters.
The composition root is the only place wiring data and presentation together.
Feature layers can use shared core errors and utilities; presentation also uses
core theme resources. Core utilities do not depend on features. DI is the outer
composition boundary and is never imported by a feature layer.

- `Book` and `ReadingFeed` are immutable; feed books and Cubit state collections
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
- `SharedPreferencesReadingCache` owns local persistence; `BookDto` and
  `ReadingFeedDto` map between the wire format and domain entities. The
  `folio.feeds.v1` key, JSON fields, enum names and ISO date encoding remain
  compatible with existing installs. A cache read never triggers a network call.
- `ReadingLibrary` loads cached shelves and derives books only from actual
  feeds. Load/add/remove/refresh share a serialized queue; a failed operation
  does not poison subsequent work. Add/remove/refresh publish feeds only after
  a successful save, and mutations require a successful cache load. Refresh
  fetches sequentially, retaining cached
  feeds for individual network failures and preserving all old state if the
  final save fails. `ReadingCubit` delegates shelf operations and owns
  loading/busy/syncing flags and UI errors in immutable `ReadingState` snapshots. Navigation, visible
  search text (with a clear action), filters
  and selected dates stay in UI. Errors persist across page navigation.
- `MonthShareCubit` depends on `MonthExporter` and `ImageSharer`. The renderer
  stays in presentation because it paints Flutter visuals. `SharePlusImageSharer`
  owns PNG payload construction and plugin result/error translation in data; its
  domain contract uses plain Dart values for the popover bounds. Each preview
  owns and disposes its exporter, cover client and decoded images.
- `ReadingApplication` closes its Cubit and HTTP client. The
  Cubit owns/disposes its library; the library borrows its repository and
  the network adapter borrows its client.
  Closed Cubits ignore late completions, stop further refresh requests,
  and do not emit new state. Already-issued cache writes
  can finish; disposal is not cancellation or rollback of persistence.

Architecture tests enforce the responsibility folders, framework-free domain
and core utilities, and inward dependency boundaries. Tests also cover library operations without a UI,
pure domain rules, literal legacy JSON, cache/repository separation,
URL construction/validation/query encoding, request/error/timeout behavior,
RSS interpretation, fake-repository connection dialogs, serialized mutation
races/failures, load-retry protection, Cubit lifecycle, search navigation,
and responsive UI flows at 320, 390 and 1400 pixels. Sample factories live only
under `test/support/`; tests do not verify a real Goodreads account or live RSS
availability. Tests use package imports across the `test`/`lib` boundary and
relative imports within each source tree, following the Flutter lints.

Calendar/export tests additionally cover date precedence and exact symbols/labels,
mixed-category counts, normalization, leap days and six-week alignment, immutable
viewed-month snapshots independent of selected day/refresh, dynamic week offsets,
all covers in cells exactly once, nonvisual full-title accessibility, rounded card
clipping/borders and absent tally/list strips, missing/corrupt/failed covers, bounded HTTP streams/deadlines and
disposal, actual 2240px PNG pixels/dimensions/opacity and high-frequency cover detail, empty months and pre-load safety limits,
preview errors/retry, duplicate request guards, share payload/filename/button
rectangle, cancellation and late completions. Responsive calendar tests include
320/390/1400px widths at 1× and 2× text scale. Native share-target behavior and
delivery still require device testing on each target platform.
