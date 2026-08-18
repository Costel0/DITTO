import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';

class HubJobs extends StatelessWidget {
  const HubJobs({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final jobs = <HubJobCard>[
      HubJobCard(
        imageAsset: 'assets/hub/background_work_area_default.png',
        fallbackIcon: Icons.build,
        title: l10n.jobWorkshopTitle,
        description: l10n.jobWorkshopDescription,
        specificInfo: const _WorkshopJobInfo(),
      ),
      HubJobCard(
        imageAsset: 'assets/hub/background_kitchen_default.png',
        fallbackIcon: Icons.restaurant,
        title: l10n.jobKitchenTitle,
        description: l10n.jobKitchenDescription,
        specificInfo: const _KitchenJobInfo(),
      ),
      HubJobCard(
        imageAsset: 'assets/hub/background_rest_area_default.png',
        fallbackIcon: Icons.eco,
        title: l10n.jobGardenTitle,
        description: l10n.jobGardenDescription,
        specificInfo: const _GardenJobInfo(),
      ),
    ];

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xE611110E),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.hubJobsTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFE6D8BD),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: jobs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) => jobs[index],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HubJobCard extends StatelessWidget {
  const HubJobCard({
    super.key,
    required this.imageAsset,
    required this.fallbackIcon,
    required this.title,
    required this.description,
    required this.specificInfo,
  });

  final String imageAsset;
  final IconData fallbackIcon;
  final String title;
  final String description;
  final Widget specificInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF4E4537)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = constraints.maxWidth < 560 ? 112.0 : 176.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: imageWidth,
                height: 164,
                child: _JobImage(
                  assetPath: imageAsset,
                  fallbackIcon: fallbackIcon,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFE4D5B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFA79E8E),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      specificInfo,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JobImage extends StatelessWidget {
  const _JobImage({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF242019)),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            fallbackIcon,
            size: 42,
            color: const Color(0xFFAD9365),
          ),
        ),
      ),
    );
  }
}

class _WorkshopJobInfo extends StatelessWidget {
  const _WorkshopJobInfo();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _JobInfoView(
      icon: Icons.build,
      label: l10n.jobWorkshopInfoLabel,
      value: l10n.jobWorkshopInfoValue,
    );
  }
}

class _KitchenJobInfo extends StatelessWidget {
  const _KitchenJobInfo();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _JobInfoView(
      icon: Icons.restaurant,
      label: l10n.jobKitchenInfoLabel,
      value: l10n.jobKitchenInfoValue,
    );
  }
}

class _GardenJobInfo extends StatelessWidget {
  const _GardenJobInfo();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _JobInfoView(
      icon: Icons.eco,
      label: l10n.jobGardenInfoLabel,
      value: l10n.jobGardenInfoValue,
    );
  }
}

class _JobInfoView extends StatelessWidget {
  const _JobInfoView({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF25221B),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF443D31)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFC0A46F)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFFBDB3A1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8F8677),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
