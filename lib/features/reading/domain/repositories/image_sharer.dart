import '../entities/image_share_result.dart';
import '../entities/month_image.dart';

abstract interface class ImageSharer {
  Future<ImageShareResult> share(
    MonthImage image,
    String fileName,
    ShareOrigin origin,
  );
}
