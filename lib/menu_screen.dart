// lib/menu_screen.dart
import 'package:flutter/material.dart';
import 'screens/ShipDex/ships_screen.dart';
import 'l10n/app_localizations.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de las secciones que tendrá tu Wiki
    final List<Map<String, dynamic>> menuItems = [
      {
        'ID': 'ship_dex',
        'title': AppLocalizations.of(context)!.menuShipDex,
        'icon': Icons.rocket_launch,
        'color': Colors.blueAccent,
      },
      {
        'ID': '',
        'title': 'DEFENSAS',
        'icon': Icons.shield,
        'color': Colors.redAccent,
      },
      {
        'ID': '',
        'title': 'EDIFICIOS',
        'icon': Icons.corporate_fare,
        'color': Colors.amber,
      },
      {
        'ID': '',
        'title': 'TECNOLOGÍAS',
        'icon': Icons.biotech,
        'color': Colors.green,
      },
      {
        'ID': '',
        'title': 'CALCULADORA',
        'icon': Icons.calculate,
        'color': Colors.purpleAccent,
      },
      {
        'ID': '',
        'title': 'SIMULADOR',
        'icon': Icons.eighteen_mp,
        'color': Colors.teal,
      }, // Icono genérico de radar/combate
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A), // Fondo oscuro estilo espacio
      appBar: AppBar(
        title: const Text(
          'OGAME WIKI & TOOLS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161925),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        // GridView.builder crea una cuadrícula que se adapta al tamaño de la pantalla
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            // Ancho máximo de cada botón grande
            childAspectRatio: 1.0,
            // Proporción 1:1 para que sean cuadrados perfectos
            crossAxisSpacing: 20,
            // Espacio horizontal entre botones
            mainAxisSpacing: 20, // Espacio vertical entre botones
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];

            return InkWell(
              onTap: () {
                if (item['ID'] == 'ship_dex') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShipDexScreen(),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  color: const Color(0xFF161925), // Fondo de la tarjeta
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item['color'].withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: item['color'].withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'], size: 50, color: item['color']),
                    const SizedBox(height: 16),
                    Text(
                      item['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
