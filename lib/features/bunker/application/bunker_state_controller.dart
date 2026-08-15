import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/bunker_state.dart';
import '../domain/bunker_state_service.dart';

/// Holds the latest server-authoritative bunker snapshot for the UI.
///
/// The state has no public setter. It can only be replaced by a successful
/// fetch from [BunkerStateService].
class BunkerStateController extends ChangeNotifier {
  BunkerStateController({
    required BunkerStateService service,
    this.pollInterval = const Duration(seconds: 30),
  }) : _service = service;

  final BunkerStateService _service;
  final Duration pollInterval;

  BunkerState? _state;
  Timer? _pollTimer;
  bool _isRefreshing = false;
  bool _isDisposed = false;
  Object? _lastError;

  BunkerState? get state => _state;
  bool get isRefreshing => _isRefreshing;
  Object? get lastError => _lastError;

  void startPolling() {
    if (_pollTimer != null) return;

    unawaited(refresh());
    _pollTimer = Timer.periodic(
      pollInterval,
      (_) => unawaited(refresh()),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    if (_isRefreshing || _isDisposed) return;

    _isRefreshing = true;
    try {
      final nextState = await _service.fetchBunkerState();
      if (_isDisposed) return;

      final hadError = _lastError != null;
      _lastError = null;
      final currentRevision = _state?.revision;
      if (currentRevision == null || nextState.revision > currentRevision) {
        _state = nextState;
        notifyListeners();
      } else if (hadError) {
        notifyListeners();
      }
    } catch (error) {
      if (_isDisposed) return;
      _lastError = error;
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopPolling();
    super.dispose();
  }
}
