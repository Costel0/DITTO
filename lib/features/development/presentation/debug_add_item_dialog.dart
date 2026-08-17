import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugItemGrantRequest {
  const DebugItemGrantRequest({
    required this.itemId,
    required this.quantity,
  });

  final String itemId;
  final int quantity;
}

/// Development-only form used by the HUB debug controls.
///
/// It deliberately contains no gameplay logic. Removing this file together
/// with the debug controls removes the complete item-grant UI.
class DebugAddItemDialog extends StatefulWidget {
  const DebugAddItemDialog({super.key});

  static Future<DebugItemGrantRequest?> show(BuildContext context) {
    return showDialog<DebugItemGrantRequest>(
      context: context,
      builder: (_) => const DebugAddItemDialog(),
    );
  }

  @override
  State<DebugAddItemDialog> createState() => _DebugAddItemDialogState();
}

class _DebugAddItemDialogState extends State<DebugAddItemDialog> {
  final _itemIdController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String? _errorText;

  @override
  void dispose() {
    _itemIdController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    final itemId = _itemIdController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());

    if (itemId.isEmpty) {
      setState(() => _errorText = 'Introduce un ID de item.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _errorText = 'La cantidad debe ser un entero mayor que 0.');
      return;
    }

    Navigator.of(context).pop(
      DebugItemGrantRequest(itemId: itemId, quantity: quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('DEBUG: Añadir item'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemIdController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'ID del item',
                hintText: 'Ej. scrap_metal',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: const <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                hintText: '1',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}
