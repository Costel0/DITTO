// lib/ships_screen.dart
import 'package:flutter/material.dart';
import 'package:game_wiki/core/utils/number_formatter.dart';

import '../../ShipUtils/ship_model.dart';
import '../../ShipUtils/ship_repository.dart';
import '../../l10n/app_localizations.dart';
import '../ShipDetail/ship_detail_screen.dart';


class ShipDexScreen extends StatelessWidget {
  const ShipDexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ShipRepository();
    final List<ShipModel> ships = repository.getAllShips(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title:  Text(AppLocalizations.of(context)!.shipDexMenu),
        backgroundColor: const Color(0xFF161925),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ships.length,
        itemBuilder: (context, index) {
          return _buildShipItem(ships[index], context);
        },
      ),
    );
  }

  Widget _buildShipItem(ShipModel ship, BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isMobile = screenWidth < 850;

    final statInfo1 = AppLocalizations.of(context)!.statCostBulk;
    final statInfo2 = AppLocalizations.of(context)!.statCostAttack;
    final statInfo3 = AppLocalizations.of(context)!.statCostCargo;

    return Card(
      color: const Color(0xFF161925),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2E354F), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShipDetailScreen(ship: ship),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          // 💡 Decidimos qué layout renderizar en función del tamaño
          child: isMobile
              ? _buildMobileLayout(ship, context)
              : _buildWideLayout(ship, context, statInfo1, statInfo2, statInfo3),
        ),
      ),
    );
  }

  // ==========================================
  // LAYOUT WEB / TABLET (Pantallas Anchas)
  // ==========================================
  Widget _buildWideLayout(ShipModel ship, BuildContext context, String info1, String info2, String info3) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 2,
          fit: FlexFit.loose,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 225),
            child: _buildShipImage(ship),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: _buildCostSection(ship, false),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: _buildShipStats(ship, context),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: _buildRapidFire(ship, context),
        ),
        const SizedBox(width: 16),

        // 💡 Nota: Asumo el uso de enums estándar de Dart (ShipType.militar)
        if (ship.type == ShipType.militar) ...[
          _buildShipComputedStats(ship, info1, info2)
        ] else if (ship.type == ShipType.civil) ...[
          _buildShipComputedStats(ship, info1, info3)
        ]
      ],
    );
  }

  // ==========================================
  // LAYOUT APP MÓVIL (Pantallas Estrechas)
  // ==========================================
  Widget _buildMobileLayout(ShipModel ship, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ship.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // 1. Imagen ocupando todo el ancho superior en formato panorámico
        _buildShipImage(ship, isMobile: true),
        const SizedBox(height: 16),

        // 2. Costes debajo de la imagen, centrados en fila
        _buildCostSection(ship, true),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Divider(color: Color(0xFF2E354F), height: 1),
        ),

        // 3. Estadísticas debajo del divisor
        _buildShipStats(ship, context, hideTitle: true),

        const SizedBox(height: 8),
        _buildRapidFire(ship, context),
      ],
    );
  }

  // ==========================================
  // WIDGETS AUXILIARES REUTILIZABLES
  // ==========================================

  // 💡 Le he quitado el "Flexible" para que el padre decida cómo lo envuelve
  Widget _buildShipImage(ShipModel ship, {bool isMobile = false}) {
    return AspectRatio(
      // 💡 Formato panorámico para móvil (16:9), formato cuadrado para Web/Tablet (1:1)
      aspectRatio: isMobile ? 16 / 9 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/${ship.imageName}.png',
            fit: BoxFit.cover, // Recortará los lados automáticamente en formato 1:1
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.rocket_launch,
                size: 40,
                color: Colors.blueAccent,
              );
            },
          ),
        ),
      ),
    );
  }

  // 💡 Le cambiamos el nombre a Section porque ahora puede ser Row o Column
  Widget _buildCostSection(ShipModel ship, bool isMobile) {
    final metalCost = ship.metalCost;
    final crystalCost = ship.crystalCost;
    final deuteriumCost = ship.deuteriumCost;
    final totalCost = metalCost + crystalCost + deuteriumCost;

    if (isMobile) {
      // ==========================================
      // MODO MÓVIL: Fila centrada (Usamos Wrap por seguridad anti-overflow)
      // ==========================================
      return Wrap(
        alignment: WrapAlignment.center, // Centra los elementos en el medio
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12.0, // Espaciado horizontal entre cada recurso
        runSpacing: 12.0, // Espaciado vertical si hace falta saltar de línea
        children: [
          _buildResourceRow(imagePath: 'assets/images/metal.png', value: metalCost),
          _buildResourceRow(imagePath: 'assets/images/crystal.png', value: crystalCost),
          _buildResourceRow(imagePath: 'assets/images/deuterium.png', value: deuteriumCost),

          // Un pequeño separador vertical para darle jerarquía al total
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFF2E354F),
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
          ),

          _buildResourceRow(
            imagePath: 'assets/resources/total_cost.png',
            value: totalCost,
            isTotal: true,
          ),
        ],
      );
    }

    // ==========================================
    // MODO WEB/TABLET: Columna original pegada a la izquierda
    // ==========================================
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildResourceRow(imagePath: 'assets/images/metal.png', value: metalCost),
        const SizedBox(height: 8),
        _buildResourceRow(imagePath: 'assets/images/crystal.png', value: crystalCost),
        const SizedBox(height: 8),
        _buildResourceRow(imagePath: 'assets/images/deuterium.png', value: deuteriumCost),
        const SizedBox(height: 10),
        _buildResourceRow(
          imagePath: 'assets/resources/total_cost.png',
          value: totalCost,
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildResourceRow({required String imagePath, required int value, bool isTotal = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start, // Mejor alineación al inicio
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.asset(
            imagePath,
            width: 32, // Un pelín más pequeño para que quepa bien en móvil
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  Icons.layers,
                  size: 20,
                  color: isTotal ? Colors.amberAccent : Colors.white70,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value.toCompactString(),
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white70,
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // 💡 Añadimos un parámetro para ocultar el título en móvil, ya que queda mejor centrado arriba
  Widget _buildShipStats(ShipModel ship, BuildContext context, {bool hideTitle = false}) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideTitle) ...[
          Text(
            ship.name.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
        ],
        // Pasamos la traducción, el valor numérico y el máximo teórico
        _buildDynamicStatBar(loc.statStructureShort, ship.structure, 150000),
        const SizedBox(height: 4),
        _buildDynamicStatBar(loc.statShieldShort, ship.shield, 800),
        const SizedBox(height: 4),
        _buildDynamicStatBar(loc.statAttackShort, ship.damage, 3000),
        const SizedBox(height: 4),
        _buildDynamicStatBar(loc.statSpeedShort, ship.speed, 40000),
        const SizedBox(height: 4),
        _buildDynamicStatBar(loc.statCargoShort, ship.cargoCapacity, 25000),
      ],
    );
  }

// Nuevo Helper con barras dinámicas y límite seguro
  Widget _buildDynamicStatBar(String label, num value, num max) {
    final double percentage = value / max;
    Color barColor;

    // Lógica de colores dinámicos: cambia orgánicamente según la plenitud de la barra
    if (value > max) {
      barColor = Colors.purpleAccent; // Valor extremo (fuera de la escala normal)
    } else if (percentage <= 0.25) {
      barColor = Colors.redAccent;
    } else if (percentage <= 0.5) {
      barColor = Colors.orangeAccent;
    } else if (percentage <= 0.8) {
      barColor = Colors.lightBlueAccent;
    } else {
      barColor = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4), // Compacto para la tarjeta
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Etiqueta (Label) - Ancho ajustado para siglas
          SizedBox(
            width: 35,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ),

          // 2. Barra Separadora Visual (Estilo holográfico/láser)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Raíl de fondo oscuro
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E354F).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Barra de progreso con resplandor
                  FractionallySizedBox(
                    widthFactor: percentage.clamp(0.0, 1.0), // Seguro contra desbordamientos de layout
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            )
                          ]
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Valor Numérico
          SizedBox(
            width: 50, // Ancho fijo para alinear los números perfectamente a la derecha
            child: Text(
              value.toCompactString(),
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar({required String label, required int value, required double max, required Color color}) {
    final double percentage = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 40, // Ligeramente más compacto para móvil
          child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: const Color(0xFF23283A),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 18,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 50,
          child: Text(
            value.toCompactString(),
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildRapidFire(ShipModel ship, BuildContext context) {
    final repository = ShipRepository();
    final pros = ship.rf.entries.where((e) => e.value > 1).toList()..sort((a, b) => b.value.compareTo(a.value));
    final inverseRf = repository.getRapidFireAgainst(context, ship.id);
    final cons = inverseRf.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    if (pros.isEmpty && cons.isEmpty) return const SizedBox.shrink();

    final visiblePros = pros.take(3);
    final visibleCons = cons.take(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visiblePros.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('RF vs: ', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                ...visiblePros.map((entry) {
                  final displayName = repository.getShipNameFormatted(context, entry.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.withOpacity(0.4), width: 0.5),
                    ),
                    child: Text('$displayName (${entry.value})', style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                  );
                }),
                if (pros.length > 3) Text('+${pros.length - 3}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
              ],
            ),
          ),
        if (visibleCons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Débil vs: ', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                ...visibleCons.map((entry) {
                  final displayName = repository.getShipNameFormatted(context, entry.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withOpacity(0.4), width: 0.5),
                    ),
                    child: Text('$displayName (${entry.value})', style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                  );
                }),
                if (cons.length > 3) Text('+${cons.length - 3}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildShipComputedStats(ShipModel ship, String statInfo1, String statInfo2) {
    final bulkCost = ship.getBulkCost();
    final damageCost = ship.getDamageCost();
    // 💡 Corregido: Llamabas a getDamageCost() dos veces, asumo que existe getCargoCost()
    final cargoCost = ship.getCargoCost();

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F16).withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(statInfo1, textAlign: TextAlign.left, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const Divider(color: Color(0xFF2E354F), height: 6),
          _buildCalculatedRow(label: 'M:', value: bulkCost[0]),
          _buildCalculatedRow(label: 'C:', value: bulkCost[1]),
          _buildCalculatedRow(label: 'D:', value: bulkCost[2]),
          const Divider(color: Color(0xFF2E354F), height: 6),
          Text(statInfo2, textAlign: TextAlign.left, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const Divider(color: Color(0xFF2E354F), height: 6),
          const SizedBox(height: 4),
          if (ship.type == ShipType.militar) ...[
            _buildCalculatedRow(label: 'M:', value: damageCost[0], textColor: Colors.amberAccent),
            _buildCalculatedRow(label: 'C:', value: damageCost[1], textColor: Colors.amberAccent),
            _buildCalculatedRow(label: 'D:', value: damageCost[2], textColor: Colors.amberAccent),
          ] else if (ship.type == ShipType.civil) ...[
            _buildCalculatedRow(label: 'M:', value: cargoCost[0], textColor: Colors.blueGrey),
            _buildCalculatedRow(label: 'C:', value: cargoCost[1], textColor: Colors.blueGrey),
            _buildCalculatedRow(label: 'D:', value: cargoCost[2], textColor: Colors.blueGrey),
          ]
        ],
      ),
    );
  }

  Widget _buildCalculatedRow({required String label, required num value, Color textColor = Colors.white70, double? rowWidth = 162.0}) {
    return Container(
      width: rowWidth,
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, textAlign: TextAlign.start, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(width: 8),
          Text(
            value.toCompactString(),
            textAlign: TextAlign.end,
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}