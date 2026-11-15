import 'dart:io' show File;

/// Reads a UTF-8 text file (Dart VM).
String readTextFile(String path) => File(path).readAsStringSync();
