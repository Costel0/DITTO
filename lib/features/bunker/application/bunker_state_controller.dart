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
    Duration pollInterval = const Duration(seconds: 30),
  }) : this._(service, pollInterval);

  BunkerStateController._(this._service, this.pollInterval);

  final BunkerStateService _service;
  final Duration pollInterval;

  BunkerState? _state;
  Timer? _pollTimer;
  Future<void>? _activeRefresh;
  Future<void>? _activeCompletionResolution;
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

  Future<void> refresh() {
    if (_isDisposed) return Future<void>.value();

    final activeResolution = _activeCompletionResolution;
    if (activeResolution != null) return activeResolution;

    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) return activeRefresh;

    final refreshFuture = _performRefresh();
    _activeRefresh = refreshFuture;
    return refreshFuture;
  }

  /// Forces a fresh read after a trusted mutation has completed.
  ///
  /// If the periodic poll is already reading Firestore, wait for it first and
  /// then fetch once more. This prevents a mutation from being hidden by a
  /// concurrent poll that started just before the server write completed.
  Future<void> refreshAfterMutation() async {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) {
      await activeRefresh;
    }
    if (_isDisposed) return;

    await refresh();
  }

  /// Requests the trusted backend resolver and adopts the resulting snapshot.
  ///
  /// Multiple countdowns can expire together, so concurrent requests are
  /// deliberately coalesced into one in-flight resolution.
  Future<void> resolveCompletedOccupations() {
    if (_isDisposed) return Future<void>.value();

    final activeResolution = _activeCompletionResolution;
    if (activeResolution != null) return activeResolution;

    final resolutionFuture = _performCompletionResolution();
    _activeCompletionResolution = resolutionFuture;
    return resolutionFuture;
  }

  Future<void> _performRefresh() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      final nextState = await _service.fetchBunkerState();
      if (_isDisposed) return;

      _lastError = null;
      _acceptState(nextState);
    } catch (error) {
      if (_isDisposed) return;
      _lastError = error;
    } finally {
      _isRefreshing = false;
      _activeRefresh = null;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> _performCompletionResolution() async {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) {
      await activeRefresh;
    }
    if (_isDisposed) return;

    _isRefreshing = true;
    notifyListeners();

    try {
      final nextState = await _service.resolveCompletedOccupations();
      if (_isDisposed) return;

      _lastError = null;
      _acceptState(nextState);
    } catch (error) {
      if (_isDisposed) return;
      _lastError = error;
    } finally {
      _isRefreshing = false;
      _activeCompletionResolution = null;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _acceptState(BunkerState nextState) {
    final currentRevision = _state?.revision;
    if (currentRevision == null || nextState.revision > currentRevision) {
      _state = nextState;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopPolling();
    super.dispose();
  }
}
