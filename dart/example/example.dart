import 'package:uuid58/uuid58.dart';

void main() {
  final id = uuid58Encode('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf');
  print(id); // XDY9dmBbcMBXqcRvYw8xJ2

  print(uuid58Decode(id)); // f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf
  print(uuid58DecodeBytes(id)); // [244, 178, 71, 253, ...]

  print(isUuid58(id)); // true
  print(isUuid58('zzzzzzzzzzzzzzzzzzzzzz')); // false: exceeds 128 bits

  try {
    uuid58Decode('not a uuid58');
  } on Uuid58Exception catch (e) {
    print(e.kind.code); // invalid_length
  }

  print(uuid58()); // a random UUIDv4, encoded
}
