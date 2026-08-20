import 'bunker_state.dart';

/// Gateway for the authoritative bunker state.
///
/// Flutter may read snapshots and request trusted server actions, but only the
/// backend is allowed to decide and persist game-state mutations.
abstract interface class BunkerStateService {
  Future<BunkerState> fetchBunkerState();

  Future<BunkerState> resolveCompletedOccupations();
}
