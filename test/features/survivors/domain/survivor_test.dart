import 'package:ditto/features/survivors/domain/survivor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('energy accepts and serializes negative integers', () {
    final survivor = Survivor.fromMap(<String, dynamic>{
      'id': 's1',
      'duplicateId': '01',
      'energy': -25,
    });

    expect(survivor.energy, -25);
    expect(survivor.toMap()['energy'], -25);
  });

  test('missing legacy energy defaults to 50', () {
    final survivor = Survivor.fromMap(<String, dynamic>{
      'id': 's1',
      'duplicateId': '01',
    });

    expect(survivor.energy, 50);
  });

  test('constructor defaults energy to 50', () {
    final survivor = Survivor(duplicateId: '01');
    expect(survivor.energy, 50);
  });

  test('fractional energy is rejected', () {
    expect(
      () => Survivor.fromMap(<String, dynamic>{
        'id': 's1',
        'duplicateId': '01',
        'energy': 1.5,
      }),
      throwsFormatException,
    );
  });
}
