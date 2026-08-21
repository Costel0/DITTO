import 'package:ditto/features/survivors/domain/survivor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('energy accepts and serializes negative integers', () {
    final survivor = Survivor.fromMap(<String, dynamic>{
      'id': 's1',
      'duplicateId': 'test_duplicate',
      'energy': -25,
    });

    expect(survivor.energy, -25);
    expect(survivor.toMap()['energy'], -25);
  });

  test('missing legacy energy uses the model default', () {
    final defaultEnergy = Survivor(duplicateId: 'test_duplicate').energy;
    final survivor = Survivor.fromMap(<String, dynamic>{
      'id': 's1',
      'duplicateId': 'test_duplicate',
    });

    expect(survivor.energy, defaultEnergy);
  });

  test('fractional energy is rejected', () {
    expect(
      () => Survivor.fromMap(<String, dynamic>{
        'id': 's1',
        'duplicateId': 'test_duplicate',
        'energy': 1.5,
      }),
      throwsFormatException,
    );
  });
}
