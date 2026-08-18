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
      if (energy != null) 'energy': energy,
      'statMods': <String, dynamic>{},
      'healthHistory': <dynamic>[],
      'equippedItemIds': <String>[],
    };
  }

  test('parses schema v3 busy survivors and negative energy', () {
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
    expect(state.busySurvivors, hasLength(1));
    expect(state.busySurvivors.single.survivorId, 's2');
    expect(state.busySurvivors.single.activity, 'expedition');
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

    expect(state.survivorById('s1')?.energy, 0);
    expect(state.busySurvivors.single.survivorId, 's2');
    expect(state.busySurvivors.single.activity, 'crafting');
  });

  test('rejects a survivor that is both idle and busy', () {
    expect(
      () => BunkerState.fromJson(<String, dynamic>{
        'schemaVersion': 3,
        'revision': 1,
        'serverUpdatedAt': '2026-08-18T12:00:00Z',
        'survivors': <dynamic>[
          survivor(id: 's1', duplicateId: '01'),
        ],
        'idleSurvivors': <String>['s1'],
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
}
