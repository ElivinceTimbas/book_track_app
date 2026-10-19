import 'dart:async';
import 'dart:typed_data';

import 'package:book_track_app/features/reading/data/export_cover_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class CoverAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions, Future<void>?)? respond;
  bool closed = false;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return await respond!(options, cancelFuture);
  }

  @override
  void close({bool force = false}) => closed = true;
}

void main() {
  late CoverAdapter adapter;
  late ExportCoverSource source;
  setUp(() {
    adapter = CoverAdapter();
    source = ExportCoverSource(
      dio: Dio()..httpClientAdapter = adapter,
      deadline: const Duration(milliseconds: 40),
    );
  });
  tearDown(() => source.dispose());

  test('only HTTP(S), streams actual bytes; source owns its client', () async {
    for (final url in [
      '',
      'file:///private/book.png',
      'data:image/png;base64,123',
      'not a url',
    ]) {
      expect(await source.load(url), isNull);
    }
    expect(adapter.calls, 0);
    adapter.respond = (_, _) async => ResponseBody.fromBytes([1, 2, 3], 200);
    expect(await source.load('https://covers.example/book.png'), [1, 2, 3]);
    source.dispose();
    expect(adapter.closed, isTrue);
    expect(await source.load('https://covers.example/book.png'), isNull);
    expect(adapter.calls, 1);
  });

  test('HTTP and transport failures produce missing-cover result', () async {
    adapter.respond = (_, _) async => ResponseBody.fromString('missing', 404);
    expect(await source.load('https://covers.example/missing'), isNull);
    adapter.respond = (options, _) async =>
        throw DioException(requestOptions: options);
    expect(await source.load('https://covers.example/offline'), isNull);
  });

  test('declared and chunked oversized images rejected', () async {
    adapter.respond = (_, _) async => ResponseBody.fromBytes(
      [1],
      200,
      headers: {
        'content-length': ['${ExportCoverSource.maxBytes + 1}'],
      },
    );
    expect(await source.load('https://covers.example/large'), isNull);
    adapter.respond = (_, _) async => ResponseBody(
      Stream.fromIterable([
        Uint8List(ExportCoverSource.maxBytes),
        Uint8List(1),
      ]),
      200,
    );
    expect(await source.load('https://covers.example/chunked'), isNull);
  });

  test(
    'deadline cancels in-flight requests and returns placeholder result',
    () async {
      var cancelled = false;
      adapter.respond = (options, cancel) async {
        await cancel;
        cancelled = true;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      };
      expect(await source.load('https://covers.example/slow'), isNull);
      expect(cancelled, isTrue);
    },
  );

  test('disposal cancels in-flight requests immediately', () async {
    final started = Completer<void>();
    final cancelled = Completer<void>();
    adapter.respond = (options, cancel) async {
      started.complete();
      await cancel;
      cancelled.complete();
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    };
    final loading = source.load('https://covers.example/pending');
    await started.future;
    source.dispose();
    await cancelled.future;
    expect(await loading, isNull);
    expect(adapter.closed, isTrue);
  });

  for (final partialBody in [false, true]) {
    for (final dispose in [false, true]) {
      test(
        '${dispose ? 'disposal' : 'deadline'} releases stalled body after headers, partial bytes: $partialBody',
        () async {
          final listening = Completer<void>();
          var subscriptionCancelled = false;
          var responseClosed = false;
          late final StreamController<Uint8List> body;
          body = StreamController<Uint8List>(
            onListen: () {
              if (partialBody) body.add(Uint8List.fromList([137, 80, 78, 71]));
              listening.complete();
            },
            onCancel: () => subscriptionCancelled = true,
          );
          addTearDown(body.close);
          adapter.respond = (_, _) async => ResponseBody(
            body.stream,
            200,
            onClose: () => responseClosed = true,
          );
          final loading = source.load('https://covers.example/stalled-body');
          await listening.future;
          if (dispose) source.dispose();
          expect(await loading.timeout(const Duration(seconds: 1)), isNull);
          expect(subscriptionCancelled, isTrue);
          expect(responseClosed, isTrue);
          expect(adapter.closed, dispose);
          // A late chunk must not resurrect a partial image or leave a listener.
          body.add(Uint8List.fromList([1, 2, 3]));
          expect(body.hasListener, isFalse);
        },
      );
    }
  }
}
