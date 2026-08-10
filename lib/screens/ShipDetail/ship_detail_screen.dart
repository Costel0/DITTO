import 'package:flutter/material.dart';

import '../../ShipUtils/ship_model.dart';
import '../../ShipUtils/ship_repository.dart';
import '../../l10n/app_localizations.dart';

class ShipDetailScreen extends StatefulWidget {
  final ShipModel ship;

  const ShipDetailScreen({Key? key, required this.ship}) : super(key: key);

  @override
  State<ShipDetailScreen> createState() => _ShipDetailScreenState();
}

class _ShipDetailScreenState extends State<ShipDetailScreen> {
  // Estado de Tecnologías de Combate
  int _techWeapons = 0;
  int _techShields = 0;
  int _techArmor = 0;

  // Estado de Tecnologías de Propulsión
  int _techCombustion = 0;
  int _techImpulse = 0;
  int _techHyperspace = 0;

  final ShipRepository _shipRepository = ShipRepository();

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F16), // Fondo ultra oscuro
      appBar: AppBar(
        backgroundColor: const Color(0xFF161925),
        elevation: 0,
        title: Text(
          widget.ship.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.blueAccent),
      ),
      // Estructura principal clara y ordenada llamando a funciones
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderImage(),
            _buildBasicInfo(),
            _buildTechModifiers(strings),
            _buildSpecifications(strings),
            _buildRapidFireSection(strings),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. CABECERA: FOTO DETALLADA CON FRANJA DE FONDO
  // ==========================================
  Widget _buildHeaderImage() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2336), // Franja un poco más clarita que el fondo habitual
        border: Border(
          bottom: BorderSide(color: Color(0xFF2E354F), width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 300,
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9, // Mantiene la proporción nativa del GIF
            child: ClipRRect(
              child: Image.asset(
                'assets/gifs/${widget.ship.imageName}.gif',
                fit: BoxFit.contain,

                // ==========================================
                // 💡 INDICADOR DE CARGA PARA RECURSOS LOCALES
                // ==========================================
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  // Si la imagen ya estaba en la caché y carga de golpe, la devolvemos tal cual
                  if (wasSynchronouslyLoaded) return child;

                  // Si 'frame' es null, el motor de Flutter todavía está procesando el GIF
                  if (frame == null) {
                    return const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                          strokeWidth: 2.0, // Un grosor fino le da un toque más tecnológico/sci-fi
                        ),
                      ),
                    );
                  }

                  // Cuando 'frame' ya no es null, mostramos la nave
                  return child;
                },

                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.rocket_launch,
                      size: 80,
                      color: Colors.blueAccent,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. INFORMACIÓN BÁSICA Y DESCRIPCIÓN
  // ==========================================
  Widget _buildBasicInfo() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo de nave tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            ),
            child: Text(
              widget.ship.type.toString().split('.').last.toUpperCase(),
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Descripción
          Text(
            widget.ship.description.isNotEmpty
                ? widget.ship.description
                : "Sin descripción técnica disponible en los archivos del hangar.",
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. MODIFICADORES: TECNOLOGÍAS
  // ==========================================
  Widget _buildTechModifiers(AppLocalizations strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161925),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E354F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.techModifiersTitle,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTechInputField(strings.technology_militar, (val) => setState(() => _techWeapons = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildTechInputField(strings.technology_shields, (val) => setState(() => _techShields = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildTechInputField(strings.technology_structure, (val) => setState(() => _techArmor = val))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(color: Color(0xFF2E354F), height: 1),
            ),

            // --- BLOQUE PROPULSIÓN ---
            Text(
              strings.techDrivesTitle, // "TECNOLOGÍAS DE PROPULSIÓN"
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTechInputField(strings.techCombustionLabel, (val) => setState(() => _techCombustion = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildTechInputField(strings.techImpulseLabel, (val) => setState(() => _techImpulse = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildTechInputField(strings.techHyperspaceLabel, (val) => setState(() => _techHyperspace = val))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. ESPECIFICACIONES (BASE / CALCULADAS)
  // ==========================================
  Widget _buildSpecifications(AppLocalizations strings) {
    // 💡 Aquí en el futuro puedes usar _techWeapons, _techShields y _techArmor
    // para sumar un % a los valores base antes de convertirlos a String.
    final finalStructure = _shipRepository.calculateTechBoost(widget.ship.structure, _techArmor);
    final finalShield = _shipRepository.calculateTechBoost(widget.ship.shield, _techShields);
    final finalDamage = _shipRepository.calculateTechBoost(widget.ship.damage, _techWeapons);

    final finalSpeed = _shipRepository.calculateSpeed(
        widget.ship,
        _techCombustion,
        _techImpulse,
        _techHyperspace
    );

    // 🛑 DEFINE AQUÍ TUS MÁXIMOS TEÓRICOS PARA CALCULAR LA BARRA
    // (Ejemplo: 9,000,000 es la estructura base de una Estrella de la Muerte)
    const double maxStructure = 450000.0;
    const double maxShield = 2500.0;
    const double maxDamage = 8500.0;
    const double maxSpeed = 200000.0;
    const double maxCargo = 40000.0;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.specificationsTitle,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow(strings.specStructure, finalStructure.toString(),
              percentage: finalStructure / maxStructure),

          _buildDetailRow(strings.specShields, finalShield.toString(),
              percentage: finalShield / maxShield),

          _buildDetailRow(strings.specDamage, finalDamage.toString(),
              percentage: finalDamage / maxDamage),

          _buildDetailRow(strings.specSpeed, finalSpeed.toString(),
              percentage: finalSpeed / maxSpeed),

          _buildDetailRow(strings.specCargo, widget.ship.cargoCapacity.toString(),
              percentage: widget.ship.cargoCapacity / maxCargo),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS DE APOYO (HELPERS)
  // ==========================================

  // Helper para los campos de texto de las tecnologías
  Widget _buildTechInputField(String label, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36, // Campo de texto compacto
          child: TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: const Color(0xFF0D0F16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF2E354F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.blueAccent),
              ),
              hintText: "0",
              hintStyle: const TextStyle(color: Colors.white24),
            ),
            onChanged: (value) {
              int parsedValue = int.tryParse(value) ?? 0;
              onChanged(parsedValue);
            },
          ),
        ),
      ],
    );
  }

  // Helper para pintar las características en formato limpio
  // Helper actualizado para pintar las características con barra de porcentaje
  Widget _buildDetailRow(String label, String value, {double percentage = 0.0}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF161925), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Centra verticalmente la línea
        children: [
          // 1. Etiqueta (Label) - Ancho fijo para alinear el inicio de todas las barras
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),

          // 2. Barra Separadora Visual (Expanded ocupa todo el centro)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Stack(
                alignment: Alignment.centerLeft, // La barra crece de izquierda a derecha
                children: [
                  // Fondo oscuro de la ruta de la barra
                  Container(
                    height: 2, // Grosor muy fino
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E354F).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Barra brillante que representa el porcentaje
                  FractionallySizedBox(
                    // .clamp asegura que si nos pasamos del máximo, no de error de layout
                    widthFactor: percentage.clamp(0.0, 1.0),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.5),
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

          // 3. Valor Numérico - Ancho fijo para que todos los números queden alineados
          SizedBox(
            width: 80,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. FUEGO RÁPIDO (RAPID FIRE) PROS Y CONS
  // ==========================================
  Widget _buildRapidFireSection(AppLocalizations strings) {
    // 1. Calcular "A Favor" (Pros)
    final pros = widget.ship.rf.entries
        .where((e) => e.value > 1)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 2. Calcular "En Contra" (Cons) usando tu lógica inversa
    final inverseRf = _shipRepository.getRapidFireAgainst(context, widget.ship.id);
    final cons = inverseRf.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Si no tiene ni fortalezas ni debilidades, ocultamos la sección por completo
    if (pros.isEmpty && cons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.rapidFireTitle.toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Bloque A Favor (Verde)
          if (pros.isNotEmpty) ...[
            _buildRfWrap(
              label: strings.rfPros,
              entries: pros,
              baseColor: Colors.greenAccent,
            ),
            if (cons.isNotEmpty) const SizedBox(height: 16), // Separador si hay ambos
          ],

          // Bloque En Contra (Rojo)
          if (cons.isNotEmpty) ...[
            _buildRfWrap(
              label: strings.rfCons,
              entries: cons,
              baseColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }

  // Helper para dibujar cada elemento de Fuego Rápido
  // Helper para agrupar y dibujar las píldoras de Fuego Rápido
  Widget _buildRfWrap({
    required String label,
    required List<MapEntry<String, int>> entries,
    required Color baseColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: baseColor.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: entries.map((entry) {
            // Obtenemos el nombre localizado usando el repositorio
            final displayName = _shipRepository.getShipNameFormatted(context, entry.key);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.05), // Fondo ultra tenue
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: baseColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'x${entry.value}',
                    style: TextStyle(
                        color: baseColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}