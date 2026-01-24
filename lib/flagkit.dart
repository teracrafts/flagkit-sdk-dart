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
export 'src/error/flagkit_exception.dart';

// HTTP
export 'src/http/http_client.dart';
export 'src/http/circuit_breaker.dart';

// Core
export 'src/core/cache.dart';

// Utils
export 'src/utils/security.dart';

// Main
export 'src/flagkit_options.dart';
export 'src/flagkit_client.dart';
export 'src/flagkit.dart';
