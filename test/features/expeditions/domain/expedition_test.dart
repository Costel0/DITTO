import 'package:flutter_test/flutter_test.dart';

import 'package:ditto/features/expeditions/domain/expedition.dart';

void main() {
  const bunker = ExpeditionCoordinates(
    sectorLetter: 'M',
    sectorNumber: 25,
    zoneIndex: 1,
  );
  const adjacent = ExpeditionCoordinates(
    sectorLetter: 'N',
    sectorNumber: 25,
    zoneIndex: 1,
  );

  ExpeditionActionDefinition action({
    required String id,
    required bool unknown,
    required Set<String> zoneTypes,
    String completion = 'interactive_outcome',
    int durationSeconds = 60,
  }) {
    return ExpeditionActionDefinition(
      id: id,
      expeditionType: 'test',
      durationSeconds: durationSeconds,
      energyCostPerSurvivor: 0,
      availableForUnknownZone: unknown,
      zoneTypes: zoneTypes,
      completion: completion,
    );
  }

  test('travel preview includes outbound and return legs', () {
    final info = ExpeditionLauncherInfo(
      bunkerCoordinates: bunker,
      zonesPerSector: 5,
      travelSecondsPerDistanceUnit: 300,
      actions: const <ExpeditionActionDefinition>[],
      knownZones: const <ExpeditionKnownZone>[],
    );

    expect(info.travelSecondsTo(adjacent), 600);
    expect(
      info.travelSecondsTo(
        const ExpeditionCoordinates(
          sectorLetter: 'M',
          sectorNumber: 25,
          zoneIndex: 2,
        ),
      ),
      60,
    );
  });

  test('unknown zones expose Explore while legacy EMPTY exposes no actions', () {
    final explore = action(
      id: 'explore',
      unknown: true,
      zoneTypes: const <String>{},
      completion: 'discover_zone',
    );
    final inspectField = action(
      id: 'inspect_field',
      unknown: false,
      zoneTypes: const <String>{'EMPTY_FIELD'},
    );
    final empty = ExpeditionKnownZone(
      coordinates: adjacent,
      zoneType: 'EMPTY',
    );

    final unknownInfo = ExpeditionLauncherInfo(
      bunkerCoordinates: bunker,
      zonesPerSector: 5,
      travelSecondsPerDistanceUnit: 300,
      actions: <ExpeditionActionDefinition>[explore, inspectField],
      knownZones: const <ExpeditionKnownZone>[],
    );
    expect(
      unknownInfo.actionsForCoordinates(adjacent).map((entry) => entry.id),
      <String>['explore'],
    );

    final knownEmptyInfo = ExpeditionLauncherInfo(
      bunkerCoordinates: bunker,
      zonesPerSector: 5,
      travelSecondsPerDistanceUnit: 300,
      actions: <ExpeditionActionDefinition>[explore, inspectField],
      knownZones: <ExpeditionKnownZone>[empty],
    );
    expect(knownEmptyInfo.actionsForCoordinates(adjacent), isEmpty);
  });

  test('Explore duration adds one minute to round-trip travel', () {
    final explore = action(
      id: 'explore',
      unknown: true,
      zoneTypes: const <String>{},
      completion: 'discover_zone',
      durationSeconds: 60,
    );
    final info = ExpeditionLauncherInfo(
      bunkerCoordinates: bunker,
      zonesPerSector: 5,
      travelSecondsPerDistanceUnit: 300,
      actions: <ExpeditionActionDefinition>[explore],
      knownZones: const <ExpeditionKnownZone>[],
    );

    expect(info.durationSecondsFor(adjacent, <ExpeditionActionDefinition>[explore]), 660);
  });
}
