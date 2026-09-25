import 'dart:typed_data';

class WebPickedImage {
  const WebPickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<WebPickedImage?> pickWebImageFile() async => null;
