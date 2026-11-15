import 'dart:js_interop';

extension type _Process._(JSObject _) implements JSObject {
  external JSObject getBuiltinModule(String id);
}

@JS('process')
external _Process get _process;

extension type _Fs._(JSObject _) implements JSObject {
  external String readFileSync(String path, String encoding);
}

/// Reads a UTF-8 text file (Node.js, for `dart test -p node`). Browsers
/// cannot read the vectors file, so the conformance tests run on the VM and
/// Node.js only.
String readTextFile(String path) =>
    (_process.getBuiltinModule('node:fs') as _Fs).readFileSync(path, 'utf8');
