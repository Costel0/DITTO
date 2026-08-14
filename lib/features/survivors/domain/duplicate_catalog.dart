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
      agility: 7,
      endurance: 6,
      scavenging: 8,
    ),
  ),
  Duplicate(
    id: '02',
    baseStats: SurvivorStats(
      strength: 8,
      agility: 4,
      endurance: 9,
      scavenging: 5,
    ),
  ),
  Duplicate(
    id: '03',
    baseStats: SurvivorStats(
      strength: 4,
      agility: 9,
      endurance: 5,
      scavenging: 7,
    ),
  ),
  Duplicate(
    id: '04',
    baseStats: SurvivorStats(
      strength: 7,
      agility: 5,
      endurance: 7,
      scavenging: 9,
    ),
  ),
];

Duplicate? duplicateById(String id) {
  for (final duplicate in predefinedDuplicates) {
    if (duplicate.id == id) return duplicate;
  }
  return null;
}
