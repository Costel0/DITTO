import 'package:flutter/widgets.dart';

class _ItemDisplayText {
  const _ItemDisplayText({
    required this.enName,
    required this.esName,
    required this.enDescription,
    required this.esDescription,
  });

  final String enName;
  final String esName;
  final String enDescription;
  final String esDescription;
}

const Map<String, _ItemDisplayText> _itemDisplayById =
    <String, _ItemDisplayText>{
  'scrap_metal': _ItemDisplayText(
    enName: 'Scrap metal',
    esName: 'Chatarra',
    enDescription: 'Recovered metal pieces useful for repairs and crafting.',
    esDescription: 'Piezas de metal recuperadas, útiles para reparaciones y fabricación.',
  ),
  'field_ration': _ItemDisplayText(
    enName: 'Field ration',
    esName: 'Ración de campo',
    enDescription: 'A compact preserved meal intended for expeditions.',
    esDescription: 'Una comida compacta y conservada pensada para expediciones.',
  ),
  'makeshift_pistol': _ItemDisplayText(
    enName: 'Makeshift pistol',
    esName: 'Pistola improvisada',
    enDescription: 'A crude but serviceable ranged weapon assembled from recovered parts.',
    esDescription: 'Un arma a distancia rudimentaria pero funcional, montada con piezas recuperadas.',
  ),
  'work_helmet': _ItemDisplayText(
    enName: 'Work helmet',
    esName: 'Casco de trabajo',
    enDescription: 'A battered industrial helmet that still offers basic head protection.',
    esDescription: 'Un casco industrial desgastado que todavía ofrece protección básica para la cabeza.',
  ),
};

String itemNameForId(BuildContext context, String id) {
  final text = _itemDisplayById[id];
  if (text == null) return id;
  return _isSpanish(context) ? text.esName : text.enName;
}

String itemDescriptionForId(BuildContext context, String id) {
  final text = _itemDisplayById[id];
  if (text == null) return '';
  return _isSpanish(context) ? text.esDescription : text.enDescription;
}

bool _isSpanish(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'es';
