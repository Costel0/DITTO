import 'package:ditto/features/bunker/domain/bunker_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> survivor({
    required String id,
    required String duplicateId,
    int? energy,
  }) {
    return <String, dynamic>{
      'id': id,
      'duplicateId': duplicateId,
      'energy': ?energy,
      'statMods': <String, dynamic>{},
      'healthHistory': <dynamic>[],
      'equippedItemIds': <String>[],
    };
  }

  test('parses schema v6 task execution and completed task registry', () {
    final state = BunkerState.fromJson(<String, dynamic>{
      'schemaVersion': 6,
      'revision': 9,
      'serverUpdatedAt': '2026-08-20T09:00:00Z',
      'survivors': <dynamic>[
        survivor(id: 's1', duplicateId: '01', energy: 20),
        survivor(id: 's2', duplicateId: '02', energy: 30),
      ],
      'idleSurvivors': <String>[],
      'busySurvivors': <dynamic>[
        <String, dynamic>{
          'survivorId': 's1',
          'taskId': 'clear_garden',
          'executionId': 'execution-1',
          'activity': 'clear_garden',
          'location': 'garden',
          'startedAt': '2026-08-20T09:00:00Z',
          'endsAt': '2026-08-20T09:05:00Z',
        },
        <String, dynamic>{
          'survivorId': 's2',
          'taskId': 'clear_garden',
          'executionId': 'execution-1',
          'activity': 'clear_garden',
          'location': 'garden',
          'startedAt': '2026-08-20T09:00:00Z',
          'endsAt': '2026-08-20T09:05:00Z',
        },
      ],
      'completedTaskIds': <String>['prepare_garden'],
      'inventory': <String, int>{},
    });

    expect(state.completedTaskIds, <String>['prepare_garden']);
    expect(state.busySurvivors.length, 2);
    expect(state.busySurvivors.first.taskId, 'clear_garden');
    expect(state.busySurvivors.first.executionId, 'execution-1');
  });

  test('parses schema v5 busy survivor location and timestamps', () {
    final state = BunkerState.fromJson(<String, dynamic>{
      'schemaVersion': 5,
      'revision': 8,
      'serverUpdatedAt': '2026-08-19T12:00:00Z',
      'survivors': <dynamic>[
        survivor(id: 's1', duplicateId: '01', energy: 20),
        survivor(id: 's2', duplicateId: '02', energy: 30),
      ],
      'idleSurvivors': <String>['s1'],
      'busySurvivors': <dynamic>[
        <String, dynamic>{
          'survivorId': 's2',
          'activity': 'clear_garden',
          'location': 'garden',
          'startedAt': '2026-08-19T12:00:01.845Z',
          'endsAt': '2026-08-19T12:10:05.999Z',
        },
      ],
      'inventory': <String, int>{},
    });

    final busy = state.busySurvivors.single;
    expect(busy.survivorId, 's2');
    expect(busy.activity, 'clear_garden');
    expect(busy.location, 'garden');
    expect(busy.startedAt, DateTime.utc(2026, 8, 19, 12, 0, 1));
    expect(busy.endsAt, DateTime.utc(2026, 8, 19, 12, 10, 5));
    expect(state.completedTaskIds, isEmpty);
  });

  test('reads schema v4 busy survivor without location', () {
    final state = BunkerState.fromJson(<String, dynamic>{
      'schemaVersion': 4,
      'revision': 7,
      'serverUpdatedAt': '2026-08-18T12:00:00Z',
      'survivors': <dynamic>[
        survivor(id: 's1', duplicateId: '01', energy: 20),
        survivor(id: 's2', duplicateId: '02', energy: 30),
      ],
      'idleSurvivors': <String>['s1'],
      'busySurvivors': <dynamic>[
        <String, dynamic>{
          'survivorId': 's2',
          'activity': 'expedition',
          'startedAt': '2026-08-18T12:00:01.845Z',
          'endsAt': '2026-08-18T12:10:05.999Z',
        },
      ],
      'inventory': <String, int>{},
    });

    final busy = state.busySurvivors.single;
    expect(busy.location, 'unknown');
    expect(busy.startedAt, DateTime.utc(2026, 8, 18, 12, 0, 1));
    expect(busy.endsAt, DateTime.utc(2026, 8, 18, 12, 10, 5));
  });

  test('reads schema v3 busy entries without dates using snapshot time', () {
    final state = BunkerState.fromJson(<String, dynamic>{
      'schemaVersion': 3,
      'revision': 7,
      'serverUpdatedAt': '2026-08-18T12:00:00Z',
      'survivors': <dynamic>[
        survivor(id: 's1', duplicateId: '01', energy: -12),
        survivor(id: 's2', duplicateId: '02', energy: 30),
      ],
      'idleSurvivors': <String>['s1'],
      'busySurvivors': <dynamic>[
        <String, dynamic>{
          'survivorId': 's2',
          'activity': 'expedition',
        },
      ],
      'inventory': <String, int>{},
    });

    expect(state.survivorById('s1')?.energy, -12);
    expect(state.busySurvivors.single.location, 'unknown');
    expect(state.busySurvivors.single.startedAt, state.serverUpdatedAt);
    expect(state.busySurvivors.single.endsAt, state.serverUpdatedAt);
  });

  test('reads legacy schema v2 busy map and missing energy', () {
    final state = BunkerState.fromJson(<String, dynamic>{
      'schemaVersion': 2,
      'revision': 3,
      'serverUpdatedAt': '2026-08-18T12:00:00Z',
      'survivors': <dynamic>[
        survivor(id: 's1', duplicateId: '01'),
        survivor(id: 's2', duplicateId: '02'),
      ],
      'idleSurvivors': <String>['s1'],
      'busySurvivors': <String, dynamic>{
        'crafting': <String>['s2'],
      },
      'inventory': <String, int>{},
    });

    expect(state.survivorById('s1')?.energy, 50);
    expect(state.busySurvivors.single.survivorId, 's2');
    expect(state.busySurvivors.single.activity, 'crafting');
    expect(state.busySurvivors.single.location, 'unknown');
    expect(state.busySurvivors.single.startedAt, state.serverUpdatedAt);
    expect(state.busySurvivors.single.endsAt, state.serverUpdatedAt);
  });

  test('schema v4 requires busy start and end timestamps', () {
    expect(
      () => BunkerState.fromJson(<String, dynamic>{
        'schemaVersion': 4,
        'revision': 1,
        'serverUpdatedAt': '2026-08-18T12:00:00Z',
        'survivors': <dynamic>[
          survivor(id: 's1', duplicateId: '01'),
        ],
        'idleSurvivors': <String>[],
        'busySurvivors': <dynamic>[
          <String, dynamic>{
            'survivorId': 's1',
            'activity': 'expedition',
          },
        ],
        'inventory': <String, int>{},
      }),
      throwsFormatException,
    );
  });

  test('schema v5 requires busy location', () {
    expect(
      () => BunkerState.fromJson(<String, dynamic>{
        'schemaVersion': 5,
        'revision': 1,
        'serverUpdatedAt': '2026-08-19T12:00:00Z',
        'survivors': <dynamic>[
          survivor(id: 's1', duplicateId: '01'),
        ],
        'idleSurvivors': <String>[],
        'busySurvivors': <dynamic>[
          <String, dynamic>{
            'survivorId': 's1',
            'activity': 'clear_garden',
            'startedAt': '2026-08-19T12:00:00Z',
            'endsAt': '2026-08-19T12:05:00Z',
          },
        ],
        'inventory': <String, int>{},
      }),
      throwsFormatException,
    );
  });

  test('rejects a survivor that is both idle and busy', () {
    expect(
      () => BunkerState.fromJson(<String, dynamic>{
        'schemaVersion': 5,
        'revision': 1,
        'serverUpdatedAt': '2026-08-19T12:00:00Z',
        'survivors': <dynamic>[
          survivor(id: 's1', duplicateId: '01'),
        ],
        'idleSurvivors': <String>['s1'],
        'busySurvivors': <dynamic>[
          <String, dynamic>{
            'survivorId': 's1',
            'activity': 'clear_garden',
            'location': 'garden',
            'startedAt': '2026-08-19T12:00:00Z',
            'endsAt': '2026-08-19T12:05:00Z',
          },
        ],
        'inventory': <String, int>{},
      }),
      throwsFormatException,
    );
  });
}
