import 'duplicate.dart';
import 'survivor_stats.dart';

/// Temporary local catalog of Duplicate archetypes.
///
/// Replace IDs/base stats here as the game design becomes final. UI and
/// survivor persistence read from this list instead of duplicating the values.
const List<Duplicate> predefinedDuplicates = <Duplicate>[
  Duplicate(
    id: '01',
    baseStats: SurvivorStats(
      strength: 6,
      dexterity: 7,
      constitution: 6,
      stealth: 8,
      care: 5,
      cunning: 7,
      charm: 6,
    ),
  ),
  Duplicate(
    id: '02',
    baseStats: SurvivorStats(
      strength: 8,
      dexterity: 4,
      constitution: 9,
      stealth: 3,
      care: 4,
      cunning: 6,
      charm: 5,
    ),
  ),
  Duplicate(
    id: '03',
    baseStats: SurvivorStats(
      strength: 4,
      dexterity: 9,
      constitution: 5,
      stealth: 9,
      care: 6,
      cunning: 8,
      charm: 7,
    ),
  ),
  Duplicate(
    id: '04',
    baseStats: SurvivorStats(
      strength: 7,
      dexterity: 5,
      constitution: 7,
      stealth: 6,
      care: 3,
      cunning: 9,
      charm: 8,
    ),
  ),
];

Duplicate? duplicateById(String id) {
  for (final duplicate in predefinedDuplicates) {
    if (duplicate.id == id) return duplicate;
  }
  return null;
}
