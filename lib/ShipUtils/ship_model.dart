// lib/ship_model.dart

class ShipModel {
  final String id;
  final String name;
  final String description;
  final String imageName;
  final int metalCost;
  final int crystalCost;
  final int deuteriumCost;
  final int structure;
  final int shield;
  final int damage;
  final int speed;
  final int cargoCapacity;
  final int consume;
  final ShipType type;
  final Map<String, int> rf;

  // Constructor con parámetros obligatorios (required)
  ShipModel({
    required this.id,
    required this.name,
    required this.imageName,
    this.description = "",
    required this.metalCost,
    required this.crystalCost,
    required this.deuteriumCost,
    required this.structure,
    required this.shield,
    required this.damage,
    required this.speed,
    required this.cargoCapacity,
    required this.consume,
    required this.type,
    this.rf = const <String, int>{}
  });

  /// Coste aproximado por cada 1000 puntos de estructura
  List<double> getBulkCost() {
    if (structure == 0) return [0.0, 0.0, 0.0];
    return [
      (metalCost / structure) * 1000,
      (crystalCost / structure) * 1000,
      (deuteriumCost / structure) * 1000,
    ];
  }

  /// Coste aproximado por cada 1000 puntos de ataque basico
  List<double> getDamageCost() {
    if (damage == 0) return [0.0, 0.0, 0.0];
    return [
      (metalCost / damage) * 1000,
      (crystalCost / damage) * 1000,
      (deuteriumCost / damage) * 1000,
    ];
  }

  List<double> getCargoCost() {
    if (cargoCapacity == 0) return [0.0, 0.0, 0.0];
    return [
      (metalCost / cargoCapacity) * 1000,
      (crystalCost / cargoCapacity) * 1000,
      (deuteriumCost / cargoCapacity) * 1000,
    ];
  }

  int getRawRf(String targetShipId) {
    return rf[targetShipId] ?? 0;
  }

  /// RAPID FIRE:

  /// Calcula la probabilidad exacta (de 0.0 a 100.0) de volver a disparar.
  /// Aplica la fórmula matemática oficial de Ogame: P = ((RF - 1) / RF) * 100
  double getRfProbability(String targetShipId) {
    final int rfValue = getRawRf(targetShipId);

    // Si el valor es negativo (RF en contra) o es 0 o 1, no hay probabilidad de repetir disparo
    if (rfValue <= 1) return 0.0;

    return ((rfValue - 1) / rfValue) * 100;
  }

  /// Devuelve un texto formateado listo para pintar en la interfaz del usuario.
  /// Ejemplo: "80%" o "Sin Fuego Rápido"
  String getRfProbabilityString(String targetShipId) {
    final double probability = getRfProbability(targetShipId);
    if (probability == 0.0) return '0%';
    return '${probability.toStringAsFixed(1)}%'; // Devuelve con un decimal limpio
  }

  /// Función de utilidad para saber si esta nave es "efectiva contra" (Fuego a favor)
  /// o si es "vulnerable a" (Fuego en contra) respecto a otra nave.
  bool hasRapidFireAgainst(String targetShipId) => getRawRf(targetShipId) > 1;
  bool hasRapidFireFrom(String targetShipId) => getRawRf(targetShipId) < 0;
}

enum ShipType {
  civil, militar
}