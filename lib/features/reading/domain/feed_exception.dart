class FeedException implements Exception {
  const FeedException(this.message);
  final String message;

  @override
  String toString() => message;
}
