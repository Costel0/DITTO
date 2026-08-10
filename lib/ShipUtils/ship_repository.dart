import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import 'ship_model.dart';

class ShipRepository {

  List<ShipModel> getAllShips(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return [
      // ==========================================
      // NAVES DE COMBATE
      // ==========================================
      ShipModel(
        id: 'cazador_ligero',
        name: strings.ship_lf ,
        imageName: 'ship_lf',
        metalCost: 3000,
        crystalCost: 1000,
        deuteriumCost: 0,
        structure: 4000,
        shield: 10,
        damage: 5,
        speed: 12500,
        cargoCapacity: 50,
        consume: 20,
        type: ShipType.militar,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'satelite_solar': 5,
        },
      ),
      ShipModel(
        id: 'cazador_pesado',
        name: strings.ship_hf,
        imageName: 'ship_hf',
        metalCost: 6000,
        crystalCost: 4000,
        deuteriumCost: 0,
        structure: 10000,
        shield: 25,
        damage: 15,
        speed: 10000,
        cargoCapacity: 100,
        consume: 75,
        type: ShipType.militar,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'nave_pequena_carga': 3,
          'satelite_solar': 5,
        },
      ),
      ShipModel(
        id: 'crucero',
        name: strings.ship_cruiser,
        imageName: 'ship_cruiser',
        metalCost: 20000,
        crystalCost: 7000,
        deuteriumCost: 2000,
        structure: 27000,
        shield: 50,
        damage: 400,
        speed: 15000,
        cargoCapacity: 800,
        consume: 300,
        type: ShipType.militar,
        rf: const <String, int>{
          'cazador_ligero': 6,
          'lanza_misiles': 10,
          'sonda_espionaje': 5,
          'satelite_solar': 5
        },
      ),
      ShipModel(
        id: 'nave_batalla',
        name: strings.ship_BC,
        imageName: 'ship_BC',
        metalCost: 45000,
        crystalCost: 15000,
        deuteriumCost: 0,
        structure: 60000,
        shield: 200,
        damage: 1000,
        speed: 10000,
        cargoCapacity: 1500,
        consume: 500,
        type: ShipType.militar,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'satelite_solar': 5,
          'explorador': 5,
        },
      ),
      ShipModel(
        id: 'acorazado',
        name: strings.ship_BS,
        imageName: 'ship_BS',
        metalCost: 30000,
        crystalCost: 40000,
        deuteriumCost: 15000,
        structure: 70000,
        shield: 400,
        damage: 700,
        speed: 10000,
        cargoCapacity: 750,
        consume: 250,
        type: ShipType.militar,
        rf: const <String, int>{
          'nave_batalla': 7,
          'crucero': 4,
          'cazador_pesado': 4,
          'sonda_espionaje': 5,
          'satelite_solar': 5,
          'nave_pequena_carga': 3,
          'nave_grande_carga': 3,
        },
      ),
      ShipModel(
        id: 'bombardero',
        name: strings.ship_bombardier,
        imageName: 'ship_bombardier',
        metalCost: 50000,
        crystalCost: 25000,
        deuteriumCost: 15000,
        structure: 75000,
        shield: 500,
        damage: 1000,
        speed: 4000,
        cargoCapacity: 500,
        consume: 700,
        type: ShipType.militar,
        rf: const <String, int>{
          'lanza_misiles': 20,
          'laser_pequeno': 20,
          'laser_grande': 10,
          'canon_gauss': 5,
          'canon_iónico': 10,
          'canon_plasma': 5,
          'sonda_espionaje': 5,
          'satelite_solar': 5
        },
      ),
      ShipModel(
        id: 'destructor',
        name: strings.ship_destroyer,
        imageName: 'ship_destroyer',
        metalCost: 60000,
        crystalCost: 50000,
        deuteriumCost: 15000,
        structure: 110000,
        shield: 500,
        damage: 2000,
        speed: 5000,
        cargoCapacity: 2000,
        consume: 1000,
        type: ShipType.militar,
        rf: const <String, int>{
          'acorazado': 2,
          'sonda_espionaje': 5,
          'satelite_solar': 5,
          'laser_pequeno': 10
        },
      ),
      ShipModel(
        id: 'segador',
        name: 'Segador',
        imageName: 'segador',
        metalCost: 85000,
        crystalCost: 55000,
        deuteriumCost: 20000,
        structure: 140000,
        shield: 700,
        damage: 2800,
        speed: 7000,
        cargoCapacity: 10000,
        consume: 1100,
        type: ShipType.militar,
        rf: const <String, int>{
          'acorazado': 7,
          'bombardero': 4,
          'destructor': 3,
          'sonda_espionaje': 5,
          'satelite_solar': 5,
        },
      ),
      ShipModel(
        id: 'explorador',
        name: 'Explorador',
        imageName: 'explorador',
        metalCost: 8000,
        crystalCost: 15000,
        deuteriumCost: 8000,
        structure: 23000,
        shield: 100,
        damage: 200,
        speed: 12000,
        cargoCapacity: 10000,
        consume: 300,
        type: ShipType.militar,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'satelite_solar': 5,
        },
      ),

      // ==========================================
      // NAVES DE TRANSPORTE / CIVILES
      // ==========================================
      ShipModel(
        id: 'nave_pequena_carga',
        name: 'Nave Pequeña de Carga',
        imageName: 'nave_pequena_carga',
        metalCost: 2000,
        crystalCost: 2000,
        deuteriumCost: 0,
        structure: 4000,
        shield: 10,
        damage: 5,
        speed: 5000,
        cargoCapacity: 5000,
        consume: 10,
        type: ShipType.civil,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'satelite_solar': 5,
        },
      ),
      ShipModel(
        id: 'nave_grande_carga',
        name: 'Nave Grande de Carga',
        imageName: 'nave_grande_carga',
        metalCost: 6000,
        crystalCost: 6000,
        deuteriumCost: 0,
        structure: 12000,
        shield: 25,
        damage: 5,
        speed: 7500,
        cargoCapacity: 25000,
        consume: 50,
        type: ShipType.civil,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'satelite_solar': 5,
        },
      ),
      ShipModel(
        id: 'estrella_muerte',
        name: 'Estrella de la Muerte',
        imageName: 'estrella_muerte',
        metalCost: 5000000,
        crystalCost: 4000000,
        deuteriumCost: 1000000,
        structure: 9000000,
        shield: 50000,
        damage: 200000,
        speed: 100,
        cargoCapacity: 1000000,
        consume: 1,
        type: ShipType.militar,
        rf: const <String, int>{
          'cazador_ligero': 200,
          'cazador_pesado': 100,
          'crucero': 33,
          'nave_batalla': 30,
          'bombardero': 25,
          'destructor': 5,
          'acorazado': 15,
          'nave_pequena_carga': 250,
          'nave_grande_carga': 250,
          'colonizador': 250,
          'reciclador': 250,
          'sonda_espionaje': 1250,
          'satelite_solar': 1250,
          'lanza_misiles': 200,
          'laser_pequeno': 200,
          'laser_grande': 100,
          'canon_gauss': 50,
          'canon_ionico': 100,
        },
      ),
      ShipModel(
        id: 'colonizador',
        name: 'Colonizador',
        imageName: 'colonizador',
        metalCost: 10000,
        crystalCost: 20000,
        deuteriumCost: 10000,
        structure: 30000,
        shield: 100,
        damage: 5,
        speed: 2500,
        cargoCapacity: 7500,
        consume: 1000,
        type: ShipType.civil,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'satelite_solar': 5,
        },
      ),
      ShipModel(
        id: 'reciclador',
        name: 'Reciclador',
        imageName: 'reciclador',
        metalCost: 10000,
        crystalCost: 6000,
        deuteriumCost: 2000,
        structure: 16000,
        shield: 10,
        damage: 1,
        speed: 2000,
        cargoCapacity: 20000,
        consume: 300,
        type: ShipType.civil,
        rf: const <String, int>{
          'sonda_espionaje': 5,
          'satelite_solar': 5,
        },
      ),
      ShipModel(
        id: 'sonda_espionaje',
        name: 'Sonda de Espionaje',
        imageName: 'sonda_espionaje',
        metalCost: 0,
        crystalCost: 1000,
        deuteriumCost: 0,
        structure: 1000,
        shield: 0,
        damage: 0,
        speed: 100000000,
        cargoCapacity: 0,
        consume: 1,
        type: ShipType.civil,
        rf: const <String, int>{},
      ),
      ShipModel(
        id: 'satelite_solar',
        name: 'Satélite Solar',
        imageName: 'satelite_solar',
        metalCost: 0,
        crystalCost: 2000,
        deuteriumCost: 500,
        structure: 2000,
        shield: 1,
        damage: 1,
        speed: 0,
        cargoCapacity: 0,
        consume: 0,
        type: ShipType.civil,
        rf: const <String, int>{},
      ),
    ];
  }



  ShipModel? findShipById(BuildContext context, String id) {
    try {
      return getAllShips(context).firstWhere((ship) => ship.id == id);
    } catch (_) {
      return null; // Devuelve null si es una defensa o id no registrado
    }
  }

  /// Estructura conveniente para la interfaz de usuario
  /// Devuelve el nombre real (traducido si existe) de un ID de nave o defensa
  String getShipNameFormatted(BuildContext context, String id) {
    final ship = findShipById(context, id);
    if (ship != null) return ship.name;

    // Tratamiento para defensas comunes si no se encuentran en la lista de naves
    return id.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  Map<String, int> getRapidFireAgainst(BuildContext context, String targetShipId) {
    final Map<String, int> weaknesses = {};
    final allShips = getAllShips(context);

    for (final attacker in allShips) {
      // Si el atacante tiene en su mapa nuestra nave con un valor mayor a 1...
      if (attacker.rf.containsKey(targetShipId) && attacker.rf[targetShipId]! > 1) {
        // Guardamos el ID del atacante y el valor del daño que nos hace
        weaknesses[attacker.id] = attacker.rf[targetShipId]!;
      }
    }
    return weaknesses;
  }

  int calculateTechBoost(int baseValue, int techLevel) {
    if (techLevel == 0) return baseValue;
    // Ogame aplica un 10% (0.1) por cada nivel de tecnología
    double multiplier = 1.0 + (techLevel * 0.1);
    return (baseValue * multiplier).round();
  }

  int calculateSpeed(ShipModel ship, int combustionLvl, int impulseLvl, int hyperspaceLvl) {
    int baseSpeed = ship.speed;
    String id = ship.id;

    // ========================================================
    // 1. EXCEPCIONES DE SALTO DE MOTOR (Mecánicas de OGame)
    // ========================================================

    // Nave Pequeña de Carga: Pasa a Motor de Impulso al nivel 5
    if (id == 'nave_pequena_carga' && impulseLvl >= 5) {
      baseSpeed = 10000;
      return (baseSpeed * (1 + (impulseLvl * 0.2))).round();
    }

    // Bombardero: Pasa a Propulsor Hiperespacial al nivel 8
    if (id == 'bombardero' && hyperspaceLvl >= 8) {
      baseSpeed = 5000;
      return (baseSpeed * (1 + (hyperspaceLvl * 0.3))).round();
    }

    // Reciclador: Tiene dos saltos de motor posibles (prioridad al más alto)
    if (id == 'reciclador') {
      if (hyperspaceLvl >= 15) {
        // Salto definitivo: Pasa a Hiperespacio al nivel 15 (Base sube a 6000)
        baseSpeed = 6000;
        return (baseSpeed * (1 + (hyperspaceLvl * 0.3))).round();
      } else if (impulseLvl >= 17) {
        // Salto intermedio: Pasa a Motor de Impulso al nivel 17 (Base sube a 4000)
        baseSpeed = 4000;
        return (baseSpeed * (1 + (impulseLvl * 0.2))).round();
      }
    }

    // ========================================================
    // 2. CÁLCULO ESTÁNDAR (Antes de saltos o naves sin saltos)
    // ========================================================

    // Naves con Motor de Combustión (10% por nivel)
    if (['cazador_ligero', 'nave_grande_carga', 'reciclador', 'sonda_espionaje', 'nave_pequena_carga'].contains(id)) {
      return (baseSpeed * (1 + (combustionLvl * 0.1))).round();
    }

    // Naves con Motor de Impulso (20% por nivel)
    // CORRECCIÓN: El bombardero se añade aquí, ya que empieza con Motor de Impulso.
    else if (['cazador_pesado', 'crucero', 'nave_colonia', 'bombardero'].contains(id)) {
      return (baseSpeed * (1 + (impulseLvl * 0.2))).round();
    }

    // Naves con Propulsor Hiperespacial (30% por nivel)
    // CORRECCIÓN: El bombardero se retira de aquí. Solo llegará si su nivel es >= 8 y se calcula en la primera sección.
    else if (['nave_batalla', 'destructor', 'estrella_muerte', 'acorazado', 'segador', 'explorador'].contains(id)) {
      return (baseSpeed * (1 + (hyperspaceLvl * 0.3))).round();
    }

    // Fallback de seguridad si el ID no coincide
    return baseSpeed;
  }
}