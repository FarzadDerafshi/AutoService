class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? fieldErrors;

  const ApiException(this.message, {this.statusCode, this.fieldErrors});

  @override
  String toString() => message;
}
