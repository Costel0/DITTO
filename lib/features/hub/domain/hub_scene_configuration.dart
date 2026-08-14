import 'dart:ui';

import 'hub_background_configuration.dart';

enum HubCharacterSlot {
  leftCompanion,
  primary,
  rightCompanion1,
  rightCompanion2,
}

class HubElementPlacement {
  const HubElementPlacement({
    required this.position,
    required this.size,
  });

  final Offset position;
  final Size size;
}

class HubSceneConfiguration {
  const HubSceneConfiguration({
    required this.canvasSize,
    required this.initialFocusX,
    required this.characterPlacements,
    required this.backgroundState,
    required this.characterBrightness,
    required this.showCoordinateGrid,
  });

  final Size canvasSize;
  final double initialFocusX;
  final Map<HubCharacterSlot, HubElementPlacement> characterPlacements;
  final HubBackgroundState backgroundState;

  /// 1.0 preserves the source PNG. Values below 1.0 darken characters slightly
  /// so they sit more naturally inside the illustrated bunker background.
  final double characterBrightness;
  final bool showCoordinateGrid;

  HubElementPlacement placementFor(HubCharacterSlot slot) {
    return characterPlacements[slot]!;
  }
}

/// Default visual layout for the bunker scene.
///
/// The primary slot deliberately preserves the position and dimensions tuned in
/// the UI before this configuration was extracted. Companion slots are vacant
/// until the player obtains additional characters.
const HubSceneConfiguration defaultHubSceneConfiguration =
    HubSceneConfiguration(
  canvasSize: Size(1440, 360),
  initialFocusX: 720,
  characterPlacements: <HubCharacterSlot, HubElementPlacement>{
    HubCharacterSlot.leftCompanion: HubElementPlacement(
      position: Offset(180, 90),
      size: Size(170, 270),
    ),
    HubCharacterSlot.primary: HubElementPlacement(
      position: Offset(390, 90),
      size: Size(170, 270),
    ),
    HubCharacterSlot.rightCompanion1: HubElementPlacement(
      position: Offset(600, 90),
      size: Size(170, 270),
    ),
    HubCharacterSlot.rightCompanion2: HubElementPlacement(
      position: Offset(810, 90),
      size: Size(170, 270),
    ),
  },
  backgroundState: HubBackgroundState(),
  characterBrightness: 0.86,
  showCoordinateGrid: true,
);
