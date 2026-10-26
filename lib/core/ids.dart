import 'dart:math';

final Random _secureRandom = Random.secure();

String newRandomId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(_secureRandom.nextInt(16).toRadixString(16));
  }
  return buffer.toString();
}
