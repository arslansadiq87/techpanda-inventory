// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class WebPickedSvg {
  const WebPickedSvg({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<WebPickedSvg?> pickWebSvgFile() {
  final completer = Completer<WebPickedSvg?>();
  final input = html.FileUploadInputElement()
    ..accept = '.svg,image/svg+xml'
    ..multiple = false
    ..style.display = 'none';
  StreamSubscription<html.Event>? focusSubscription;

  void complete(WebPickedSvg? value) {
    focusSubscription?.cancel();
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
        complete(WebPickedSvg(name: file.name, bytes: result));
      } else if (result is ByteBuffer) {
        complete(WebPickedSvg(name: file.name, bytes: result.asUint8List()));
      } else {
        complete(null);
      }
    });
    reader.readAsArrayBuffer(file);
  });

  // Browsers do not consistently emit a change event when the chooser is
  // cancelled. Complete after focus returns so the upload button is re-enabled.
  focusSubscription = html.window.onFocus.listen((_) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted && input.files?.isNotEmpty != true) {
        complete(null);
      }
    });
  });

  html.document.body?.append(input);
  input.click();
  return completer.future;
}
