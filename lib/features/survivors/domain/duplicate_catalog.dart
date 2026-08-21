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
      strength: 2,
      dexterity: 4,
      constitution: 2,
      stealth: 4,
      care: 4,
      cunning: 3,
      charm: 4,
    ),
  ),
  Duplicate(
    id: '02',
    baseStats: SurvivorStats(
      strength: 5,
      dexterity: 2,
      constitution: 5,
      stealth: 1,
      care: 2,
      cunning: 3,
      charm: 3,
    ),
  ),
  Duplicate(
    id: '03',
    baseStats: SurvivorStats(
      strength: 3,
      dexterity: 5,
      constitution: 2,
      stealth: 3,
      care: 4,
      cunning: 3,
      charm: 4,
    ),
  ),
  Duplicate(
    id: '04',
    baseStats: SurvivorStats(
      strength: 0,
      dexterity: 0,
      constitution: 0,
      stealth: 0,
      care: 0,
      cunning: 0,
      charm: 0,
    ),
  ),
  Duplicate(
    id: '05',
    baseStats: SurvivorStats(
      strength: 0,
      dexterity: 0,
      constitution: 0,
      stealth: 0,
      care: 0,
      cunning: 0,
      charm: 0,
    ),
  ),
];

/// Duplicates that a brand-new user may choose during bunker creation.
///
/// Later Duplicates remain in [predefinedDuplicates] so they can be acquired by
/// gameplay or development tools without automatically becoming starter choices.
const Set<String> initialSelectableDuplicateIds = <String>{
  '01',
  '02',
  '03',
  '04',
};

final List<Duplicate> initialSelectableDuplicates = List<Duplicate>.unmodifiable(
  predefinedDuplicates.where(
    (duplicate) => initialSelectableDuplicateIds.contains(duplicate.id),
  ),
);

bool isInitialSelectableDuplicateId(String id) =>
    initialSelectableDuplicateIds.contains(id);

Duplicate? duplicateById(String id) {
  for (final duplicate in predefinedDuplicates) {
    if (duplicate.id == id) return duplicate;
  }
  return null;
}
