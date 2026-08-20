import 'dart:async';

import 'package:ditto/features/bunker/application/bunker_state_controller.dart';
import 'package:ditto/features/bunker/domain/bunker_state.dart';
import 'package:ditto/features/bunker/domain/bunker_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledBunkerStateService implements BunkerStateService {
  final Completer<BunkerState> fetchCompleter = Completer<BunkerState>();
  final Completer<BunkerState> resolutionCompleter = Completer<BunkerState>();
  int resolutionCalls = 0;

  @override
  Future<BunkerState> fetchBunkerState() => fetchCompleter.future;

  @override
  Future<BunkerState> resolveCompletedOccupations() {
    resolutionCalls += 1;
    return resolutionCompleter.future;
  }
}

BunkerState _emptyState({int revision = 1}) {
  return BunkerState.fromJson(<String, dynamic>{
    'schemaVersion': 5,
    'revision': revision,
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

    service.fetchCompleter.complete(_emptyState());
    await refresh;

    expect(controller.isRefreshing, isFalse);
    expect(refreshingStates.last, isFalse);

    controller.dispose();
  });

  test('completion resolution is coalesced and adopts newer state', () async {
    final service = _ControlledBunkerStateService();
    final controller = BunkerStateController(service: service);

    service.fetchCompleter.complete(_emptyState());
    await controller.refresh();

    final first = controller.resolveCompletedOccupations();
    final second = controller.resolveCompletedOccupations();

    expect(service.resolutionCalls, 1);
    expect(controller.isRefreshing, isTrue);

    service.resolutionCompleter.complete(_emptyState(revision: 2));
    await Future.wait(<Future<void>>[first, second]);

    expect(controller.state?.revision, 2);
    expect(controller.isRefreshing, isFalse);
    expect(service.resolutionCalls, 1);

    controller.dispose();
  });
}
