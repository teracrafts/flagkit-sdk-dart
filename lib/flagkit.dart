/// Official Dart/Flutter SDK for FlagKit feature flag management.
library flagkit;

// Types
export 'src/types/flag_type.dart';
export 'src/types/flag_value.dart';
export 'src/types/flag_state.dart';
export 'src/types/evaluation_context.dart';
export 'src/types/evaluation_reason.dart';
export 'src/types/evaluation_result.dart';

// Error
export 'src/error/error_code.dart';
export 'src/error/error_sanitizer.dart';
export 'src/error/flagkit_exception.dart';

// HTTP
export 'src/http/http_client.dart';
export 'src/http/circuit_breaker.dart';
export 'src/http/retry.dart';

// Core
export 'src/core/cache.dart';
export 'src/core/context_manager.dart';
export 'src/core/event_queue.dart';
export 'src/core/event_persistence.dart';
export 'src/core/polling_manager.dart';

// Utils
export 'src/utils/security.dart';

// Main
export 'src/flagkit_options.dart';
export 'src/flagkit_client.dart';
export 'src/flagkit.dart';
