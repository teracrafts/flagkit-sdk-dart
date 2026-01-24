import 'dart:async';
import 'dart:math';

/// Polling state enumeration.
enum PollingState {
  /// Polling is stopped.
  stopped,

  /// Polling is running.
  running,

  /// Polling is paused.
  paused,
}

/// Configuration for polling.
class PollingConfig {
  /// Polling interval in milliseconds. Default: 30000 (30 seconds)
  final int intervalMs;

  /// Jitter in milliseconds to prevent thundering herd. Default: 1000
  final int jitterMs;

  /// Backoff multiplier for consecutive errors. Default: 2.0
  final double backoffMultiplier;

  /// Maximum interval in milliseconds. Default: 300000 (5 minutes)
  final int maxIntervalMs;

  /// Maximum consecutive errors before pausing. Default: 10
  final int maxConsecutiveErrors;

  const PollingConfig({
    this.intervalMs = 30000,
    this.jitterMs = 1000,
    this.backoffMultiplier = 2.0,
    this.maxIntervalMs = 300000,
    this.maxConsecutiveErrors = 10,
  });

  /// Default polling configuration.
  static const defaultConfig = PollingConfig();
}

/// Callback for poll operations.
typedef PollCallback = Future<void> Function();

/// Manages background polling for flag updates.
///
/// Features:
/// - Configurable polling interval
/// - Jitter to prevent thundering herd
/// - Exponential backoff on errors
/// - State management (running, stopped, paused)
class PollingManager {
  final PollingConfig _config;
  final PollCallback _onPoll;
  final void Function(Object error)? _onError;
  final void Function()? _onSuccess;
  final Random _random;

  int _currentIntervalMs;
  int _consecutiveErrors = 0;
  Timer? _timer;
  PollingState _state = PollingState.stopped;
  DateTime? _lastPollTime;
  DateTime? _lastSuccessTime;

  PollingManager({
    required PollCallback onPoll,
    PollingConfig config = PollingConfig.defaultConfig,
    void Function(Object error)? onError,
    void Function()? onSuccess,
    Random? random,
  })  : _config = config,
        _onPoll = onPoll,
        _onError = onError,
        _onSuccess = onSuccess,
        _random = random ?? Random(),
        _currentIntervalMs = config.intervalMs;

  /// Gets the current polling state.
  PollingState get state => _state;

  /// Returns true if polling is running.
  bool get isRunning => _state == PollingState.running;

  /// Returns true if polling is paused.
  bool get isPaused => _state == PollingState.paused;

  /// Returns true if polling is stopped.
  bool get isStopped => _state == PollingState.stopped;

  /// Gets the current polling interval.
  int get currentIntervalMs => _currentIntervalMs;

  /// Gets the number of consecutive errors.
  int get consecutiveErrors => _consecutiveErrors;

  /// Gets the time of the last poll attempt.
  DateTime? get lastPollTime => _lastPollTime;

  /// Gets the time of the last successful poll.
  DateTime? get lastSuccessTime => _lastSuccessTime;

  /// Starts polling.
  ///
  /// If already running, this is a no-op.
  void start() {
    if (_state == PollingState.running) {
      return;
    }

    _state = PollingState.running;
    _scheduleNext();
  }

  /// Stops polling.
  ///
  /// If already stopped, this is a no-op.
  void stop() {
    if (_state == PollingState.stopped) {
      return;
    }

    _state = PollingState.stopped;
    _cancelTimer();
  }

  /// Pauses polling.
  ///
  /// Polling can be resumed with [resume].
  void pause() {
    if (_state != PollingState.running) {
      return;
    }

    _state = PollingState.paused;
    _cancelTimer();
  }

  /// Resumes paused polling.
  void resume() {
    if (_state != PollingState.paused) {
      return;
    }

    _state = PollingState.running;
    _scheduleNext();
  }

  /// Forces an immediate poll.
  ///
  /// Does not affect the regular polling schedule.
  Future<void> pollNow() async {
    // Cancel any scheduled poll to avoid double polling
    _cancelTimer();

    // Execute poll
    await _executePoll();

    // Reschedule if still running
    if (_state == PollingState.running) {
      _scheduleNext();
    }
  }

  /// Resets the polling manager to initial state.
  ///
  /// Clears error counts and resets interval.
  /// Does not change the running state.
  void reset() {
    _consecutiveErrors = 0;
    _currentIntervalMs = _config.intervalMs;

    if (_state == PollingState.running) {
      _cancelTimer();
      _scheduleNext();
    }
  }

  /// Records a successful poll (for manual control).
  void recordSuccess() {
    _onSuccessInternal();
  }

  /// Records a failed poll (for manual control).
  void recordError() {
    _onErrorInternal();
  }

  void _scheduleNext() {
    if (_state != PollingState.running) {
      return;
    }

    final delay = _getNextDelay();
    _timer = Timer(Duration(milliseconds: delay), () => _poll());
  }

  Future<void> _poll() async {
    if (_state != PollingState.running) {
      return;
    }

    await _executePoll();
    _scheduleNext();
  }

  Future<void> _executePoll() async {
    _lastPollTime = DateTime.now();

    try {
      await _onPoll();
      _onSuccessInternal();
      _onSuccess?.call();
    } catch (error) {
      _onErrorInternal();
      _onError?.call(error);
    }
  }

  void _onSuccessInternal() {
    _consecutiveErrors = 0;
    _currentIntervalMs = _config.intervalMs;
    _lastSuccessTime = DateTime.now();
  }

  void _onErrorInternal() {
    _consecutiveErrors++;

    // Apply exponential backoff
    _currentIntervalMs = min(
      (_currentIntervalMs * _config.backoffMultiplier).toInt(),
      _config.maxIntervalMs,
    );

    // Pause if too many consecutive errors
    if (_consecutiveErrors >= _config.maxConsecutiveErrors) {
      pause();
    }
  }

  int _getNextDelay() {
    // Add jitter to prevent thundering herd
    final jitter = (_random.nextDouble() * _config.jitterMs).toInt();
    return _currentIntervalMs + jitter;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
