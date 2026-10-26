double readDouble(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  return value is num ? value.toDouble() : fallback;
}

int readInt(Map<String, dynamic> json, String key, int fallback) {
  final value = json[key];
  return value is num ? value.toInt() : fallback;
}

bool readBool(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  return value is bool ? value : fallback;
}

String readString(Map<String, dynamic> json, String key, String fallback) {
  final value = json[key];
  return value is String ? value : fallback;
}

Map<String, dynamic> readMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is Map<String, dynamic> ? value : const {};
}

T readEnum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
