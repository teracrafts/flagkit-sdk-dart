import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'circuit_breaker.dart';
import '../error/error_code.dart';
import '../error/flagkit_exception.dart';
import '../flagkit_options.dart';
import '../utils/security.dart';

/// SDK version for User-Agent header.
const String sdkVersion = '1.0.0';

/// HTTP client with retry logic and circuit breaker.
///
/// Handles all HTTP communication with the FlagKit API including:
/// - Automatic retries with exponential backoff
/// - Circuit breaker for fault tolerance
/// - Request timeout handling
/// - Request signing (HMAC-SHA256) for POST requests
/// - Key rotation on 401 errors
class FlagKitHttpClient {
  final FlagKitOptions options;
  final http.Client _client;
  final CircuitBreaker _circuitBreaker;
  final Random _random = Random();
  final KeyRotationManager _keyRotation;

  FlagKitHttpClient(this.options, {http.Client? client, int? localPort})
      : _client = client ?? http.Client(),
        _circuitBreaker = CircuitBreaker(
          threshold: options.circuitBreakerThreshold,
          resetTimeout: options.circuitBreakerResetTimeout,
        ),
        _keyRotation = KeyRotationManager(
          primaryApiKey: options.apiKey,
          secondaryApiKey: options.secondaryApiKey,
        );

  /// Gets the currently active API key.
  String get activeApiKey => _keyRotation.activeKey;

  /// Returns true if using the primary API key.
  bool get isPrimaryKeyActive => _keyRotation.isPrimaryActive;

  /// Returns true if a secondary key is configured.
  bool get hasSecondaryKey => _keyRotation.hasSecondaryKey;

  /// Resets to use the primary API key.
  void resetToPrimaryKey() => _keyRotation.resetToPrimary();

  /// Gets the effective base URL from options.
  String get _effectiveBaseUrl => options.effectiveBaseUrl;

  /// Gets the circuit breaker instance.
  CircuitBreaker get circuitBreaker => _circuitBreaker;

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
    final url = Uri.parse('$_effectiveBaseUrl$path');

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
    final url = Uri.parse('$_effectiveBaseUrl$path');
    final bodyString = jsonEncode(body);
    final headers = _getPostHeaders(bodyString);

    final response = await _client
        .post(
          url,
          headers: headers,
          body: bodyString,
        )
        .timeout(options.timeout, onTimeout: () {
      throw FlagKitException.networkError(
          ErrorCode.httpTimeout, 'Request timed out');
    });

    return _handleResponse(response, fromJson);
  }

  Future<void> _doPostVoid(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$_effectiveBaseUrl$path');
    final bodyString = jsonEncode(body);
    final headers = _getPostHeaders(bodyString);

    final response = await _client
        .post(
          url,
          headers: headers,
          body: bodyString,
        )
        .timeout(options.timeout, onTimeout: () {
      throw FlagKitException.networkError(
          ErrorCode.httpTimeout, 'Request timed out');
    });

    if (!_isSuccess(response.statusCode)) {
      throw _statusToError(response.statusCode, response.body);
    }
  }

  /// Gets the headers for API requests per spec.
  Map<String, String> get _headers => {
        'X-API-Key': _keyRotation.activeKey,
        'User-Agent': 'FlagKit-Dart/$sdkVersion',
        'X-FlagKit-SDK-Version': sdkVersion,
        'X-FlagKit-SDK-Language': 'dart',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Gets headers for POST requests, including signature headers if enabled.
  Map<String, String> _getPostHeaders(String body) {
    final headers = Map<String, String>.from(_headers);

    if (options.enableRequestSigning) {
      final signatureHeaders = getSignatureHeaders(body, _keyRotation.activeKey);
      headers.addAll(signatureHeaders);
    }

    return headers;
  }

  Future<T> _executeWithRetry<T>(Future<T> Function() action) {
    return _circuitBreaker.execute(() async {
      Object? lastError;
      var keyRotationAttempted = false;

      for (var attempt = 0; attempt <= options.retryAttempts; attempt++) {
        try {
          return await action();
        } catch (e) {
          lastError = e;

          // Check if we should rotate keys on 401 error
          if (e is FlagKitException &&
              e.code == ErrorCode.httpUnauthorized &&
              !keyRotationAttempted &&
              _keyRotation.hasSecondaryKey) {
            final rotated = _keyRotation.shouldRotateOnError(401);
            if (rotated) {
              keyRotationAttempted = true;
              // Don't count this as a retry attempt, just retry with new key
              attempt--;
              continue;
            }
          }

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
