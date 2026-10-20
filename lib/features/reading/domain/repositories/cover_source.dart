import 'dart:typed_data';

abstract interface class CoverSource {
  Future<Uint8List?> load(String url);
  void dispose();
}
