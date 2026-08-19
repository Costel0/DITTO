import 'dart:async';

import 'package:ditto/features/bunker/application/bunker_state_controller.dart';
import 'package:ditto/features/bunker/domain/bunker_state.dart';
import 'package:ditto/features/bunker/domain/bunker_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledBunkerStateService implements BunkerStateService {
  final Completer<BunkerState> completer = Completer<BunkerState>();

  @override
  Future<BunkerState> fetchBunkerState() => completer.future;
}

BunkerState _emptyState() {
  return BunkerState.fromJson(<String, dynamic>{
    'schemaVersion': 5,
    'revision': 1,
    'serverUpdatedAt': '2026-08-19T17:00:00Z',
    'survivors': <dynamic>[],
    'idleSurvivors': <String>[],
    'busySurvivors': <dynamic>[],
    'inventory': <String, int>{},
  });
}

void main() {
  test('refresh notifies when loading starts and finishes', () async {
    final service = _ControlledBunkerStateService();
    final controller = BunkerStateController(service: service);
    final refreshingStates = <bool>[];

    controller.addListener(() {
      refreshingStates.add(controller.isRefreshing);
    });

    final refresh = controller.refresh();

    expect(controller.isRefreshing, isTrue);
    expect(refreshingStates, contains(true));

    service.completer.complete(_emptyState());
    await refresh;

    expect(controller.isRefreshing, isFalse);
    expect(refreshingStates.last, isFalse);

    controller.dispose();
  });
}
