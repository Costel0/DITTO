import 'package:flutter/material.dart';

import '../../../auth/application/session_controller.dart';
import '../../../survivors/domain/duplicate_catalog.dart';

/// Temporary development-only controls for manipulating the local game state.
///
/// Keep all visual debug controls here so they can be removed from the HUB with
/// a single widget/file deletion once the real server-authoritative flows exist.
class HubDebugControls extends StatefulWidget {
  const HubDebugControls({
    super.key,
    required this.sessionController,
    required this.onResetProfile,
    required this.resetTooltip,
  });

  final SessionController sessionController;
  final Future<void> Function() onResetProfile;
  final String resetTooltip;

  @override
  State<HubDebugControls> createState() => _HubDebugControlsState();
}

class _HubDebugControlsState extends State<HubDebugControls> {
  bool _isResetting = false;
  bool _isAddingSurvivor = false;

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
    if (_isResetting || _isAddingSurvivor) return;
    setState(() => _isResetting = true);
    try {
      await widget.onResetProfile();
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _addNextSurvivor() async {
    if (_isAddingSurvivor || _isResetting) return;
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

  @override
  Widget build(BuildContext context) {
    final nextDuplicateId = _nextMissingDuplicateId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: widget.resetTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: _isAddingSurvivor || _isResetting ? null : _resetProfile,
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
          onPressed: nextDuplicateId == null ||
                  _isAddingSurvivor ||
                  _isResetting
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
      ],
    );
  }
}
