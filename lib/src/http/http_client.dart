import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'circuit_breaker.dart';
import '../error/error_code.dart';
import '../error/flagkit_exception.dart';
import '../flagkit_options.dart';

/// HTTP client with retry logic and circuit breaker.
class FlagKitHttpClient {
  static const _baseUrl = 'https://api.flagkit.dev/api/v1';

  final FlagKitOptions options;
  final http.Client _client;
  final CircuitBreaker _circuitBreaker;
  final Random _random = Random();

  FlagKitHttpClient(this.options)
      : _client = http.Client(),
        _circuitBreaker = CircuitBreaker(
          threshold: options.circuitBreakerThreshold,
          resetTimeout: options.circuitBreakerResetTimeout,
        );

  Future<T> get<T>(String path, T Function(Map<String, dynamic>) fromJson) {
    return _executeWithRetry(() => _doGet(path, fromJson));
  }

  Future<T> post<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return _executeWithRetry(() => _doPost(path, body, fromJson));
  }

  Future<void> postVoid(String path, Map<String, dynamic> body) {
    return _executeWithRetry(() => _doPostVoid(path, body));
  }

  Future<T> _doGet<T>(
      String path, T Function(Map<String, dynamic>) fromJson) async {
    final url = Uri.parse('$_baseUrl$path');

    final response = await _client
        .get(url, headers: _headers)
        .timeout(options.timeout, onTimeout: () {
      throw FlagKitException.networkError(
          ErrorCode.httpTimeout, 'Request timed out');
    });

    return _handleResponse(response, fromJson);
  }

  Future<T> _doPost<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final url = Uri.parse('$_baseUrl$path');

    final response = await _client
        .post(
          url,
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(options.timeout, onTimeout: () {
      throw FlagKitException.networkError(
          ErrorCode.httpTimeout, 'Request timed out');
    });

    return _handleResponse(response, fromJson);
  }

  Future<void> _doPostVoid(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl$path');

    final response = await _client
        .post(
          url,
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(options.timeout, onTimeout: () {
      throw FlagKitException.networkError(
          ErrorCode.httpTimeout, 'Request timed out');
    });

    if (!_isSuccess(response.statusCode)) {
      throw _statusToError(response.statusCode, response.body);
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${options.apiKey}',
        'X-API-Key': options.apiKey,
        'User-Agent': 'FlagKit-Dart/1.0.0',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<T> _executeWithRetry<T>(Future<T> Function() action) {
    return _circuitBreaker.execute(() async {
      Object? lastError;

      for (var attempt = 0; attempt <= options.retryAttempts; attempt++) {
        try {
          return await action();
        } catch (e) {
          lastError = e;

          if (!_isRetryable(e) || attempt >= options.retryAttempts) {
            rethrow;
          }

          final delay = _calculateBackoff(attempt);
          await Future.delayed(delay);
        }
      }

      throw lastError ?? FlagKitException.networkError(
        ErrorCode.networkError,
        'Retry failed',
      );
    });
  }

  bool _isRetryable(Object error) {
    if (error is FlagKitException) {
      return const {
        ErrorCode.httpTimeout,
        ErrorCode.httpNetworkError,
        ErrorCode.httpServerError,
        ErrorCode.networkError,
        ErrorCode.networkTimeout,
      }.contains(error.code);
    }
    return false;
  }

  Duration _calculateBackoff(int attempt) {
    const baseDelay = 1000.0;
    const maxDelay = 30000.0;
    const multiplier = 2.0;

    var delay = baseDelay * pow(multiplier, attempt);
    delay = min(delay, maxDelay);

    // Add jitter (0-25%)
    final jitter = delay * 0.25 * _random.nextDouble();
    delay += jitter;

    return Duration(milliseconds: delay.toInt());
  }

  T _handleResponse<T>(
      http.Response response, T Function(Map<String, dynamic>) fromJson) {
    if (_isSuccess(response.statusCode)) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return fromJson(json);
      } catch (e) {
        throw FlagKitException.networkError(
          ErrorCode.httpInvalidResponse,
          'Failed to parse response: $e',
          e,
        );
      }
    } else {
      throw _statusToError(response.statusCode, response.body);
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  FlagKitException _statusToError(int statusCode, String body) {
    final (code, category) = switch (statusCode) {
      400 => (ErrorCode.httpBadRequest, 'Client Error'),
      401 => (ErrorCode.httpUnauthorized, 'Authentication Error'),
      403 => (ErrorCode.httpForbidden, 'Authorization Error'),
      404 => (ErrorCode.httpNotFound, 'Not Found'),
      429 => (ErrorCode.httpRateLimited, 'Rate Limited'),
      >= 500 => (ErrorCode.httpServerError, 'Server Error'),
      _ when statusCode >= 400 && statusCode < 500 => (
          ErrorCode.httpBadRequest,
          'Client Error'
        ),
      _ => (ErrorCode.httpServerError, 'Server Error'),
    };

    return FlagKitException.networkError(
      code,
      '$category: $statusCode - $body',
    );
  }

  void close() {
    _client.close();
  }
}
