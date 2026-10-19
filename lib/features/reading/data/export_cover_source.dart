import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/month_export.dart';

class ExportCoverSource implements CoverSource {
  ExportCoverSource({Dio? dio, this.deadline = const Duration(seconds: 12)})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              followRedirects: true,
              maxRedirects: 3,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final length = response.headers.value('content-length');
          if ((int.tryParse(length ?? '') ?? 0) > maxBytes) {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                error: 'Cover exceeds byte limit',
              ),
            );
          }
          handler.next(response);
        },
      ),
    );
  }

  static const maxBytes = 3 * 1024 * 1024;
  final Dio _dio;
  final Duration deadline;
  final _requests = <CancelToken>{};
  bool _disposed = false;

  @override
  Future<Uint8List?> load(String url) async {
    final uri = Uri.tryParse(url);
    if (_disposed ||
        uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    final requestCancel = CancelToken();
    _requests.add(requestCancel);
    void cancelRequest() => requestCancel.cancel('Cover deadline reached');
    final timer = Timer(deadline, cancelRequest);
    // Closing the source cancels the adapter, including in-flight streams.
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: requestCancel,
        options: Options(responseType: ResponseType.stream),
      );
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream) {
        if (_disposed || bytes.length + chunk.length > maxBytes) {
          requestCancel.cancel('Cover cancelled or too large');
          return null;
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } on Exception {
      return null;
    } finally {
      requestCancel.cancel('Cover complete');
      timer.cancel();
      _requests.remove(requestCancel);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final request in _requests) {
      request.cancel('Preview closed');
    }
    _requests.clear();
    _dio.close(force: true);
  }
}
