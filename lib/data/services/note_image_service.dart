import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

import '../../core/utils/utils.dart';
import '../models/models.dart';

class NoteImageException implements Exception {
  const NoteImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NoteImageService {
  const NoteImageService();

  static const int maxImagesPerNote = 12;
  static const int maxSourceBytes = 12 * 1024 * 1024;
  static const int maxStoredBytes = 2 * 1024 * 1024;

  Future<List<NoteImage>> pickImages({required int availableSlots}) async {
    if (availableSlots <= 0) {
      throw const NoteImageException('每条笔记最多添加 12 张图片');
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: availableSlots > 1,
      withData: true,
    );
    if (result == null) {
      return const [];
    }

    final selectedFiles = result.files.take(availableSlots);
    final images = <NoteImage>[];
    for (final file in selectedFiles) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw NoteImageException('无法读取图片“${file.name}”');
      }
      images.add(await prepareImage(name: file.name, bytes: bytes));
    }
    return images;
  }

  Future<NoteImage> prepareImage({
    required String name,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw const NoteImageException('图片内容为空');
    }
    if (bytes.length > maxSourceBytes) {
      throw const NoteImageException('单张原图不能超过 12 MB');
    }

    Uint8List compressed;
    try {
      compressed = await compute(_compressImage, bytes);
    } on FormatException {
      throw const NoteImageException('图片格式无法识别，请选择 JPG、PNG 或 WebP');
    }

    if (compressed.length > maxStoredBytes) {
      throw const NoteImageException('图片压缩后仍超过 2 MB，请选择尺寸更小的图片');
    }

    return NoteImage(
      id: GuidUtil.generate(),
      name: _normalizedName(name),
      mimeType: 'image/jpeg',
      base64Data: base64Encode(compressed),
    );
  }

  String _normalizedName(String name) {
    final trimmed = name.trim();
    final baseName = trimmed.isEmpty ? 'note-image' : trimmed.split('.').first;
    return '$baseName.jpg';
  }
}

Uint8List _compressImage(Uint8List source) {
  var decoded = image_lib.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('Unsupported image data');
  }

  decoded = image_lib.bakeOrientation(decoded);
  if (decoded.width > 1600 || decoded.height > 1600) {
    decoded = decoded.width >= decoded.height
        ? image_lib.copyResize(
            decoded,
            width: 1600,
            interpolation: image_lib.Interpolation.average,
          )
        : image_lib.copyResize(
            decoded,
            height: 1600,
            interpolation: image_lib.Interpolation.average,
          );
  }

  var encoded = Uint8List.fromList(image_lib.encodeJpg(decoded, quality: 84));
  if (encoded.length <= NoteImageService.maxStoredBytes) {
    return encoded;
  }

  final smaller = decoded.width >= decoded.height
      ? image_lib.copyResize(
          decoded,
          width: 1280,
          interpolation: image_lib.Interpolation.average,
        )
      : image_lib.copyResize(
          decoded,
          height: 1280,
          interpolation: image_lib.Interpolation.average,
        );
  encoded = Uint8List.fromList(image_lib.encodeJpg(smaller, quality: 70));
  return encoded;
}
