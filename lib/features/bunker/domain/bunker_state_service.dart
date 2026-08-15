import 'bunker_state.dart';

/// Read-only gateway for the authoritative bunker state.
///
/// Mutation methods are intentionally absent: the Flutter client may request
/// snapshots, but only the server will be allowed to change game state.
abstract interface class BunkerStateService {
  Future<BunkerState> fetchBunkerState();
}
