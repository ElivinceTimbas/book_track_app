import 'dart:typed_data';

class MonthImage {
  const MonthImage(this.bytes, this.width, this.height, this.summary);
  final Uint8List bytes;
  final int width;
  final int height;
  final String summary;
}
