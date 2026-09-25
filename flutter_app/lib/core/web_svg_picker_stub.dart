import 'dart:typed_data';

class WebPickedSvg {
  const WebPickedSvg({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<WebPickedSvg?> pickWebSvgFile() async => null;
