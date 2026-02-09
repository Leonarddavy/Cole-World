// Web-only helper for turning picked bytes into a playable URL.
//
// Uses `dart:js_interop` instead of `dart:html`/`dart:js_util` (deprecated).
import 'dart:js_interop';
import 'dart:typed_data';

@JS('URL')
external _JSURLClass get _urlClass;

extension type _JSURLClass(JSObject _) implements JSObject {
  external String createObjectURL(_JSBlob blob);
  external void revokeObjectURL(String url);
}

@JS('Blob')
extension type _JSBlob(JSObject _) implements JSObject {
  external factory _JSBlob.new_(
    JSArray<JSAny?> parts, [
    _JSBlobPropertyBag? options,
  ]);
}

extension type _JSBlobPropertyBag(JSObject _) implements JSObject {
  external factory _JSBlobPropertyBag.new_({String? type});
}

String? createObjectUrlFromBytes(
  List<int> bytes, {
  String? mimeType,
}) {
  if (bytes.isEmpty) {
    return null;
  }

  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final parts = <JSAny?>[data.toJS].toJS;
  final blob = _JSBlob.new_(
    parts,
    _JSBlobPropertyBag.new_(type: mimeType ?? 'audio/mpeg'),
  );
  return _urlClass.createObjectURL(blob);
}

void revokeObjectUrl(String url) {
  _urlClass.revokeObjectURL(url);
}
