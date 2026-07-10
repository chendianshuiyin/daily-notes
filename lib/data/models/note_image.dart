import 'dart:convert';
import 'dart:typed_data';

class NoteImage {
  const NoteImage({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.base64Data,
  });

  final String id;
  final String name;
  final String mimeType;
  final String base64Data;

  Uint8List get bytes => base64Decode(base64Data);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mimeType': mimeType,
      'base64Data': base64Data,
    };
  }

  factory NoteImage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final mimeType = json['mimeType'];
    final base64Data = json['base64Data'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Image ID is missing.');
    }
    if (name is! String || mimeType is! String || base64Data is! String) {
      throw const FormatException('Image metadata is invalid.');
    }
    if (!mimeType.startsWith('image/')) {
      throw const FormatException('Image MIME type is invalid.');
    }

    base64Decode(base64Data);
    return NoteImage(
      id: id,
      name: name,
      mimeType: mimeType,
      base64Data: base64Data,
    );
  }
}
