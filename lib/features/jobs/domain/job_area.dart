enum JobArea {
  workshop,
  kitchen,
  garden,
}

extension JobAreaDefinition on JobArea {
  String get id {
    switch (this) {
      case JobArea.workshop:
        return 'workshop';
      case JobArea.kitchen:
        return 'kitchen';
      case JobArea.garden:
        return 'garden';
    }
  }

  String get cardAssetPath {
    switch (this) {
      case JobArea.workshop:
        return 'assets/jobs/workshop_card.png';
      case JobArea.kitchen:
        return 'assets/jobs/kitchen_card.png';
      case JobArea.garden:
        return 'assets/jobs/garden_card.png';
    }
  }

  String get coverAssetPath {
    switch (this) {
      case JobArea.workshop:
        return 'assets/jobs/workshop_cover.png';
      case JobArea.kitchen:
        return 'assets/jobs/kitchen_cover.png';
      case JobArea.garden:
        return 'assets/jobs/garden_cover.png';
    }
  }
}
