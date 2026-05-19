import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

/// Compresses [src] into a JPEG at [destPath], capping the longest side at
/// [maxDimension] px and targeting [minQuality]–100 quality.
///
/// Returns the written [File]. Throws if compression produces an empty result.
Future<File> compressImage(
  File src,
  String destPath, {
  int maxDimension = 1200,
  int minQuality = 75,
}) async {
  // Always write as .jpg regardless of source format.
  final jpegPath = p.setExtension(destPath, '.jpg');

  final result = await FlutterImageCompress.compressAndGetFile(
    src.absolute.path,
    jpegPath,
    minWidth: maxDimension,
    minHeight: maxDimension,
    quality: minQuality,
    keepExif: false,
    format: CompressFormat.jpeg,
  );

  if (result == null) throw Exception('Image compression failed for ${src.path}');
  return File(result.path);
}
