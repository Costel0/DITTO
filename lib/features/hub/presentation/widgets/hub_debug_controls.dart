import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../auth/application/session_controller.dart';
import '../../../development/presentation/debug_add_item_dialog.dart';
import '../../../survivors/domain/duplicate_catalog.dart';

/// Temporary development-only controls for manipulating server game state.
///
/// Keep all visual debug controls here so they can be removed from the HUB with
/// a single widget/file deletion once the real server-authoritative flows exist.
/// This widget renders nothing outside debug builds.
class HubDebugControls extends StatefulWidget {
  const HubDebugControls({
    super.key,
    required this.sessionController,
    required this.onResetProfile,
    this.onItemAdded,
    required this.resetTooltip,
  });

  final SessionController sessionController;
  final Future<void> Function() onResetProfile;
  final Future<void> Function()? onItemAdded;
  final String resetTooltip;

  @override
  State<HubDebugControls> createState() => _HubDebugControlsState();
}

class _HubDebugControlsState extends State<HubDebugControls> {
  bool _isResetting = false;
  bool _isAddingSurvivor = false;
  bool _isAddingItem = false;

  bool get _isBusy => _isResetting || _isAddingSurvivor || _isAddingItem;

  String? get _nextMissingDuplicateId {
    final ownedIds = widget.sessionController.survivors
        .map((survivor) => survivor.duplicateId)
        .toSet();

    for (final duplicate in predefinedDuplicates) {
      if (!ownedIds.contains(duplicate.id)) return duplicate.id;
    }
    return null;
  }

  Future<void> _resetProfile() async {
    if (_isBusy) return;
    setState(() => _isResetting = true);
    try {
      await widget.onResetProfile();
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _addNextSurvivor() async {
    if (_isBusy) return;
    final duplicateId = _nextMissingDuplicateId;
    if (duplicateId == null) return;

    setState(() => _isAddingSurvivor = true);
    final added = await widget.sessionController.addSurvivorForTesting(
      duplicateId,
    );
    if (!mounted) return;

    setState(() => _isAddingSurvivor = false);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DEBUG: Could not add Survivor.')),
      );
    }
  }

  Future<void> _addItem() async {
    if (_isBusy) return;

    final request = await DebugAddItemDialog.show(context);
    if (!mounted || request == null) return;

    setState(() => _isAddingItem = true);
    try {
      final added = await widget.sessionController.addItemForTesting(
        itemId: request.itemId,
        quantity: request.quantity,
      );
      if (!mounted) return;

      if (!added) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'DEBUG: Could not add item. Verify that /items is synced to Firestore (npm run sync:items:exact).',
            ),
          ),
        );
        return;
      }

      final onItemAdded = widget.onItemAdded;
      if (onItemAdded != null) {
        await onItemAdded();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'DEBUG: Added ${request.quantity} × ${request.itemId}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAddingItem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final nextDuplicateId = _nextMissingDuplicateId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: widget.resetTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: _isBusy ? null : _resetProfile,
          icon: _isResetting
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.restart_alt_rounded,
                  size: 20,
                  color: Color(0xFF817866),
                ),
        ),
        IconButton(
          tooltip: nextDuplicateId == null
              ? 'DEBUG: All predefined Survivors owned'
              : 'DEBUG: Add Survivor $nextDuplicateId',
          visualDensity: VisualDensity.compact,
          onPressed: nextDuplicateId == null || _isBusy
              ? null
              : _addNextSurvivor,
          icon: _isAddingSurvivor
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 19,
                  color: Color(0xFF817866),
                ),
        ),
        IconButton(
          tooltip: 'DEBUG: Add item',
          visualDensity: VisualDensity.compact,
          onPressed: _isBusy ? null : _addItem,
          icon: _isAddingItem
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.add_box_outlined,
                  size: 19,
                  color: Color(0xFF817866),
                ),
        ),
      ],
    );
  }
}
