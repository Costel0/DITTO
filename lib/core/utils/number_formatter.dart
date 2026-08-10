import 'package:intl/intl.dart';

import '../../ShipUtils/ship_model.dart';

extension NumberFormatting on num {
  /// Formatea un número a un string compacto (ej. 1.5K, 2.3M)
  String toCompactString() {
    if (this >= 1000000) {
      double value = this / 1000000;
      // Regresa 1 decimal si no es entero (ej: 1.5M), si es entero regresa sin decimales (ej: 2M)
      return '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      double value = this / 1000;
      return '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)}K';
    } else {
      return this % 1 == 0 ? toInt().toString() : toStringAsFixed(1);
    }
  }
}

extension ShipFinder on List<ShipModel> {
  ShipModel? findById(String id) {
    try {
      return firstWhere((ship) => ship.id == id);
    } catch (_) {
      return null;
    }
  }
}