enum HubArea {
  entrance,
  kitchen,
  workArea,
  restArea,
  lockers,
  beds,
}

enum HubAreaState {
  defaultState,
  state2,
}

enum HubAreaOrder {
  leftToRight,
  rightToLeft,
}

const List<HubArea> hubAreasLeftToRight = <HubArea>[
  HubArea.beds,
  HubArea.lockers,
  HubArea.restArea,
  HubArea.workArea,
  HubArea.kitchen,
  HubArea.entrance,
];

/// PNG file names available for each area state.
///
/// Keep file names here instead of scattering them through UI code. The game
/// can freely change an area's current [HubAreaState]; the resolver below turns
/// that state into the corresponding asset path.
const Map<HubArea, Map<HubAreaState, String>> hubAreaStatePngNames =
    <HubArea, Map<HubAreaState, String>>{
  HubArea.entrance: <HubAreaState, String>{
    HubAreaState.defaultState: 'background_entrance_default.png',
    HubAreaState.state2: 'background_entrance_state_2.png',
  },
  HubArea.kitchen: <HubAreaState, String>{
    HubAreaState.defaultState: 'background_kitchen_default.png',
    HubAreaState.state2: 'background_kitchen_state_2.png',
  },
  HubArea.workArea: <HubAreaState, String>{
    HubAreaState.defaultState: 'background_work_area_default.png',
    HubAreaState.state2: 'background_work_area_state_2.png',
  },
  HubArea.restArea: <HubAreaState, String>{
    HubAreaState.defaultState: 'background_rest_area_default.png',
    HubAreaState.state2: 'background_rest_area_state_2.png',
  },
  HubArea.lockers: <HubAreaState, String>{
    HubAreaState.defaultState: 'background_lockers_default.png',
    HubAreaState.state2: 'background_lockers_state_2.png',
  },
  HubArea.beds: <HubAreaState, String>{
    HubAreaState.defaultState: 'background_beds_default.png',
    HubAreaState.state2: 'background_beds_state_2.png',
  },
};

class HubBackgroundState {
  const HubBackgroundState({
    this.areaStates = const <HubArea, HubAreaState>{},
    this.order = HubAreaOrder.leftToRight,
  });

  /// Current state of each area. Missing entries intentionally resolve to the
  /// area's default state.
  final Map<HubArea, HubAreaState> areaStates;

  /// Normal order is entrance -> kitchen -> work -> rest -> lockers -> beds.
  /// Reverse order mirrors that sequence.
  final HubAreaOrder order;
}

class HubBackgroundSegment {
  const HubBackgroundSegment({
    required this.area,
    required this.assetPath,
    required this.defaultAssetPath,
  });

  final HubArea area;
  final String assetPath;

  /// Used by the presentation layer if [assetPath] cannot be loaded at runtime.
  final String defaultAssetPath;
}

const String _hubAreaAssetDirectory = 'assets/hub';

List<HubBackgroundSegment> resolveHubBackgroundSegments(
  HubBackgroundState state,
) {
  final areas = state.order == HubAreaOrder.leftToRight
      ? hubAreasLeftToRight
      : hubAreasLeftToRight.reversed;

  return <HubBackgroundSegment>[
    for (final area in areas) _resolveAreaSegment(area, state.areaStates[area]),
  ];
}

HubBackgroundSegment _resolveAreaSegment(
  HubArea area,
  HubAreaState? requestedState,
) {
  final stateMapping = hubAreaStatePngNames[area]!;
  final defaultPng = stateMapping[HubAreaState.defaultState]!;
  final selectedPng = stateMapping[requestedState] ?? defaultPng;

  return HubBackgroundSegment(
    area: area,
    assetPath: '$_hubAreaAssetDirectory/$selectedPng',
    defaultAssetPath: '$_hubAreaAssetDirectory/$defaultPng',
  );
}
