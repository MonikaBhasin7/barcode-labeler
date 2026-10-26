String safeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '-')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  return cleaned.isEmpty ? 'Untitled' : cleaned;
}
