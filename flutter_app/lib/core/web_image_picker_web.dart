// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class WebPickedImage {
  const WebPickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<WebPickedImage?> pickWebImageFile() {
  final completer = Completer<WebPickedImage?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false
    ..style.display = 'none';

  void complete(WebPickedImage? value) {
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onError.first.then((_) => complete(null));
    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is Uint8List) {
        complete(WebPickedImage(name: file.name, bytes: result));
      } else if (result is ByteBuffer) {
        complete(WebPickedImage(name: file.name, bytes: result.asUint8List()));
      } else {
        complete(null);
      }
    });
    reader.readAsArrayBuffer(file);
  });

  html.document.body?.append(input);
  input.click();
  return completer.future;
}
