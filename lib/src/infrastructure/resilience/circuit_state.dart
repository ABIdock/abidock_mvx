/// Circuit breaker states for fault tolerance management.
/// Controls request flow through closed, open, and half-open states.
enum CircuitState {
  /// Circuit is closed - requests allowed through.
  closed,

  /// Circuit is open - requests blocked.
  open,

  /// Circuit testing recovery - limited requests allowed.
  halfOpen,
}
