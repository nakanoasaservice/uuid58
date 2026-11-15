import 'dart:convert' show jsonDecode;

import 'read_file_io.dart' if (dart.library.js_interop) 'read_file_node.dart';

/// Path of the shared test vectors, relative to the package root (the working
/// directory of `dart test`).
const _path = '../spec/vectors.json';

/// The parsed contents of `spec/vectors.json`.
final Map<String, Object?> vectors =
    jsonDecode(readTextFile(_path)) as Map<String, Object?>;

/// The list of cases at [path], such as `['encode', 'invalid']`.
List<Map<String, Object?>> cases(List<String> path) {
  Object? node = vectors;
  for (final key in path) {
    node = (node as Map<String, Object?>)[key];
  }
  final list = (node as List<Object?>).cast<Map<String, Object?>>();
  if (list.isEmpty) throw StateError('no cases at $path');
  return list;
}
