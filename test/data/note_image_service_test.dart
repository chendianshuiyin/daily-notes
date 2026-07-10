import 'dart:typed_data';

import 'package:daily_notes/data/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  const service = NoteImageService();

  test('compresses and normalizes a selected image', () async {
    final source = image_lib.Image(width: 2200, height: 1100);
    final sourceBytes = Uint8List.fromList(image_lib.encodePng(source));

    final attachment = await service.prepareImage(
      name: 'wide-picture.png',
      bytes: sourceBytes,
    );
    final decoded = image_lib.decodeJpg(attachment.bytes);

    expect(attachment.name, 'wide-picture.jpg');
    expect(attachment.mimeType, 'image/jpeg');
    expect(attachment.bytes.length, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
    expect(decoded.height, 800);
  });

  test('rejects empty image data', () async {
    expect(
      () => service.prepareImage(name: 'empty.png', bytes: Uint8List(0)),
      throwsA(isA<NoteImageException>()),
    );
  });
}
