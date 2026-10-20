import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/image_share_exception.dart';
import '../../domain/entities/image_share_result.dart';
import '../../domain/entities/month_image.dart';
import '../../domain/repositories/image_sharer.dart';

class SharePlusImageSharer implements ImageSharer {
  SharePlusImageSharer({Future<ShareResult> Function(ShareParams)? share})
    : _share = share ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams) _share;

  @override
  Future<ImageShareResult> share(
    MonthImage image,
    String fileName,
    ShareOrigin origin,
  ) async {
    try {
      final result = await _share(
        ShareParams(
          files: [
            XFile.fromData(image.bytes, mimeType: 'image/png', name: fileName),
          ],
          fileNameOverrides: [fileName],
          text: image.summary,
          title: 'Folio — ${fileName.substring(6, 13)}',
          sharePositionOrigin: Rect.fromLTWH(
            origin.left,
            origin.top,
            origin.width,
            origin.height,
          ),
        ),
      );
      return switch (result.status) {
        ShareResultStatus.dismissed => ImageShareResult.dismissed,
        ShareResultStatus.unavailable => ImageShareResult.unavailable,
        ShareResultStatus.success => ImageShareResult.selected,
      };
    } on MissingPluginException {
      throw const ImageShareException(
        'Sharing needs a full app rebuild after installation. '
        'Stop and rebuild Folio, then try again.',
      );
    }
  }
}
