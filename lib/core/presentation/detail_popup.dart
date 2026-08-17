import 'package:flutter/material.dart';

/// Shared visual shell for game detail dialogs.
///
/// Feature-specific dialogs provide the title, preview and body while this
/// widget owns the common modal layout, close action and sizing.
class DetailPopup extends StatelessWidget {
  const DetailPopup({
    super.key,
    required this.title,
    required this.preview,
    required this.children,
    this.maxWidth = 520,
  });

  final String title;
  final Widget preview;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF171713),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: const BorderSide(color: Color(0xFF5A4E3B)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFE7D9BE),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: preview),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 18),
                ...children,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
