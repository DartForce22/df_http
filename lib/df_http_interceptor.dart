abstract class DfHttpInterceptor {
  Future<void> onRequest(Map<String, String> headers) async {}
}
