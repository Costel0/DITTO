import 'package:ditto/features/survivors/domain/duplicate_catalog.dart';
import 'package:ditto/features/survivors/domain/survivor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Duplicate 05 exists with placeholder zero base stats', () {
    final duplicate = duplicateById('05');

    expect(duplicate, isNotNull);
    expect(duplicate!.baseStats.strength, 0);
    expect(duplicate.baseStats.dexterity, 0);
    expect(duplicate.baseStats.constitution, 0);
    expect(duplicate.baseStats.stealth, 0);
    expect(duplicate.baseStats.care, 0);
    expect(duplicate.baseStats.cunning, 0);
    expect(duplicate.baseStats.charm, 0);
    expect(duplicate.idleAssetPath, 'assets/characters/survivor_05_idle.png');
    expect(
      duplicate.dormantAssetPath,
      'assets/characters/survivor_05_Dorment.png',
    );
  });

  test('only Duplicates 01-04 are selectable for a new user', () {
    expect(
      initialSelectableDuplicates.map((duplicate) => duplicate.id).toList(),
      <String>['01', '02', '03', '04'],
    );
    expect(isInitialSelectableDuplicateId('04'), isTrue);
    expect(isInitialSelectableDuplicateId('05'), isFalse);
    expect(duplicateById('05'), isNotNull);
  });

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
