import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../types/flag_state.dart';

/// Connection states for streaming.
enum StreamingState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Response from the stream token endpoint.
class _StreamTokenResponse {
  final String token;
  final int expiresIn;

  _StreamTokenResponse({required this.token, required this.expiresIn});

  factory _StreamTokenResponse.fromJson(Map<String, dynamic> json) {
    return _StreamTokenResponse(
      token: json['token'] as String,
      expiresIn: json['expiresIn'] as int,
    );
  }
}

/// Streaming configuration.
class StreamingConfig {
  final bool enabled;
  final Duration reconnectInterval;
  final int maxReconnectAttempts;
  final Duration heartbeatInterval;

  const StreamingConfig({
    this.enabled = true,
    this.reconnectInterval = const Duration(milliseconds: 3000),
    this.maxReconnectAttempts = 3,
    this.heartbeatInterval = const Duration(milliseconds: 30000),
  });

  static const StreamingConfig defaultConfig = StreamingConfig();
}

/// Callback types for streaming events.
typedef FlagUpdateCallback = void Function(FlagState flag);
typedef FlagDeleteCallback = void Function(String key);
typedef FlagsResetCallback = void Function(List<FlagState> flags);
typedef FallbackCallback = void Function();

/// Manages Server-Sent Events (SSE) connection for real-time flag updates.
///
/// Security: Uses token exchange pattern to avoid exposing API keys in URLs.
/// 1. Fetches short-lived token via POST with API key in header
/// 2. Connects to SSE endpoint with disposable token in URL
///
/// Features:
/// - Secure token-based authentication
/// - Automatic token refresh before expiry
/// - Automatic reconnection with exponential backoff
/// - Graceful degradation to polling after max failures
/// - Heartbeat monitoring for connection health
class StreamingManager {
  final String _baseUrl;
  final String Function() _getApiKey;
  final StreamingConfig _config;
  final FlagUpdateCallback _onFlagUpdate;
  final FlagDeleteCallback _onFlagDelete;
  final FlagsResetCallback _onFlagsReset;
  final FallbackCallback _onFallbackToPolling;

  StreamingState _state = StreamingState.disconnected;
  int _consecutiveFailures = 0;
  DateTime _lastHeartbeat = DateTime.now();
  http.Client? _client;
  StreamSubscription<String>? _subscription;
  Timer? _tokenRefreshTimer;
  Timer? _heartbeatTimer;
  Timer? _retryTimer;

  StreamingManager({
    required String baseUrl,
    required String Function() getApiKey,
    StreamingConfig? config,
    required FlagUpdateCallback onFlagUpdate,
    required FlagDeleteCallback onFlagDelete,
    required FlagsResetCallback onFlagsReset,
    required FallbackCallback onFallbackToPolling,
  })  : _baseUrl = baseUrl,
        _getApiKey = getApiKey,
        _config = config ?? StreamingConfig.defaultConfig,
        _onFlagUpdate = onFlagUpdate,
        _onFlagDelete = onFlagDelete,
        _onFlagsReset = onFlagsReset,
        _onFallbackToPolling = onFallbackToPolling;

  /// Gets the current connection state.
  StreamingState get state => _state;

  /// Checks if streaming is connected.
  bool get isConnected => _state == StreamingState.connected;

  /// Starts the streaming connection.
  void connect() {
    if (_state == StreamingState.connected ||
        _state == StreamingState.connecting) {
      return;
    }

    _state = StreamingState.connecting;
    _initiateConnection();
  }

  /// Stops the streaming connection.
  void disconnect() {
    _cleanup();
    _state = StreamingState.disconnected;
    _consecutiveFailures = 0;
  }

  /// Retries the streaming connection.
  void retryConnection() {
    if (_state == StreamingState.connected ||
        _state == StreamingState.connecting) {
      return;
    }
    _consecutiveFailures = 0;
    connect();
  }

  Future<void> _initiateConnection() async {
    try {
      // Step 1: Fetch short-lived stream token
      final tokenResponse = await _fetchStreamToken();

      // Step 2: Schedule token refresh at 80% of TTL
      _scheduleTokenRefresh(
        Duration(milliseconds: (tokenResponse.expiresIn * 0.8 * 1000).toInt()),
      );

      // Step 3: Create SSE connection with token
      await _createConnection(tokenResponse.token);
    } catch (e) {
      _handleConnectionFailure();
    }
  }

  Future<_StreamTokenResponse> _fetchStreamToken() async {
    final tokenUrl = '$_baseUrl/sdk/stream/token';

    final response = await http.post(
      Uri.parse(tokenUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': _getApiKey(),
      },
      body: '{}',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch stream token: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return _StreamTokenResponse.fromJson(data);
  }

  void _scheduleTokenRefresh(Duration delay) {
    _tokenRefreshTimer?.cancel();

    _tokenRefreshTimer = Timer(delay, () async {
      try {
        final tokenResponse = await _fetchStreamToken();
        _scheduleTokenRefresh(
          Duration(
              milliseconds: (tokenResponse.expiresIn * 0.8 * 1000).toInt()),
        );
      } catch (e) {
        disconnect();
        connect();
      }
    });
  }

  Future<void> _createConnection(String token) async {
    final streamUrl = '$_baseUrl/sdk/stream?token=$token';

    _client = http.Client();
    final request = http.Request('GET', Uri.parse(streamUrl));
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        _handleConnectionFailure();
        return;
      }

      _handleOpen();
      _readEvents(response.stream);
    } catch (e) {
      _handleConnectionFailure();
    }
  }

  void _handleOpen() {
    _state = StreamingState.connected;
    _consecutiveFailures = 0;
    _lastHeartbeat = DateTime.now();
    _startHeartbeatMonitor();
  }

  void _readEvents(Stream<List<int>> stream) {
    String? eventType;
    final dataBuffer = StringBuffer();

    final lineStream = stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    _subscription = lineStream.listen(
      (line) {
        final trimmedLine = line.trim();

        // Empty line = end of event
        if (trimmedLine.isEmpty) {
          if (eventType != null && dataBuffer.isNotEmpty) {
            _processEvent(eventType!, dataBuffer.toString());
            eventType = null;
            dataBuffer.clear();
          }
          return;
        }

        // Parse SSE format
        if (trimmedLine.startsWith('event:')) {
          eventType = trimmedLine.substring(6).trim();
        } else if (trimmedLine.startsWith('data:')) {
          dataBuffer.write(trimmedLine.substring(5).trim());
        }
      },
      onError: (error) {
        _handleConnectionFailure();
      },
      onDone: () {
        if (_state == StreamingState.connected) {
          _handleConnectionFailure();
        }
      },
    );
  }

  void _processEvent(String eventType, String data) {
    try {
      switch (eventType) {
        case 'flag_updated':
          final flagData = json.decode(data) as Map<String, dynamic>;
          final flag = FlagState.fromJson(flagData);
          _onFlagUpdate(flag);
          break;

        case 'flag_deleted':
          final deleteData = json.decode(data) as Map<String, dynamic>;
          _onFlagDelete(deleteData['key'] as String);
          break;

        case 'flags_reset':
          final flagsData = json.decode(data) as List<dynamic>;
          final flags = flagsData
              .map((f) => FlagState.fromJson(f as Map<String, dynamic>))
              .toList();
          _onFlagsReset(flags);
          break;

        case 'heartbeat':
          _lastHeartbeat = DateTime.now();
          break;
      }
    } catch (e) {
      // Failed to process event
    }
  }

  void _handleConnectionFailure() {
    _cleanup();
    _consecutiveFailures++;

    if (_consecutiveFailures >= _config.maxReconnectAttempts) {
      _state = StreamingState.failed;
      _onFallbackToPolling();
      _scheduleStreamingRetry();
    } else {
      _state = StreamingState.reconnecting;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    final delay = _getReconnectDelay();

    Timer(delay, () {
      connect();
    });
  }

  Duration _getReconnectDelay() {
    final baseDelay = _config.reconnectInterval.inMilliseconds;
    final backoff = pow(2, _consecutiveFailures - 1);
    final delay = baseDelay * backoff;
    // Cap at 30 seconds
    return Duration(milliseconds: min(delay.toInt(), 30000));
  }

  void _scheduleStreamingRetry() {
    _retryTimer?.cancel();

    _retryTimer = Timer(const Duration(minutes: 5), () {
      retryConnection();
    });
  }

  void _startHeartbeatMonitor() {
    _stopHeartbeatMonitor();

    final checkInterval = Duration(
      milliseconds: (_config.heartbeatInterval.inMilliseconds * 1.5).toInt(),
    );

    _heartbeatTimer = Timer(checkInterval, () {
      final timeSince = DateTime.now().difference(_lastHeartbeat);
      final threshold = Duration(
        milliseconds: _config.heartbeatInterval.inMilliseconds * 2,
      );

      if (timeSince > threshold) {
        _handleConnectionFailure();
      } else {
        _startHeartbeatMonitor();
      }
    });
  }

  void _stopHeartbeatMonitor() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _stopHeartbeatMonitor();
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Closes the streaming manager.
  void close() {
    disconnect();
  }
}
