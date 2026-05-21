class SandboxSecurityConfig {
  final Duration executionTimeout;
  final int memoryLimitBytes;
  final int maxNetworkRequests;
  final Duration networkTimeout;

  const SandboxSecurityConfig({
    this.executionTimeout = const Duration(seconds: 30),
    this.memoryLimitBytes = 50 * 1024 * 1024, // 50MB
    this.maxNetworkRequests = 10,
    this.networkTimeout = const Duration(seconds: 15),
  });
}

class SandboxException implements Exception {
  final String message;
  final String? pluginName;
  final StackTrace? stackTrace;

  SandboxException(this.message, {this.pluginName, this.stackTrace});

  @override
  String toString() {
    final plugin = pluginName != null ? '[$pluginName] ' : '';
    return 'SandboxException: $plugin$message';
  }
}

class TimeoutException extends SandboxException {
  TimeoutException(String pluginName, Duration timeout)
      : super(
          'Execution timed out after ${timeout.inSeconds}s',
          pluginName: pluginName,
        );
}

class MemoryLimitException extends SandboxException {
  MemoryLimitException(String pluginName, int limitBytes)
      : super(
          'Memory limit exceeded: ${limitBytes ~/ (1024 * 1024)}MB',
          pluginName: pluginName,
        );
}
