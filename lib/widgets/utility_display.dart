import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';

class UtilityDisplay extends StatelessWidget {
  final PropertyUtilities utilities;
  final bool compact;

  const UtilityDisplay({
    super.key,
    required this.utilities,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _UtilityItem(
        icon: Icons.water_drop,
        label: 'Water',
        value: utilities.water,
        valueLabels: const {
          UtilityResponsibility.tenant: 'Tenant',
          UtilityResponsibility.landlord: 'Landlord',
          UtilityResponsibility.shared: 'Shared',
        },
      ),
      _UtilityItem(
        icon: Icons.electric_bolt,
        label: 'Electricity',
        value: utilities.electricity,
        valueLabels: const {
          UtilityResponsibility.tenant: 'Tenant',
          UtilityResponsibility.landlord: 'Landlord',
          UtilityResponsibility.shared: 'Shared',
        },
      ),
      _UtilityItem(
        icon: Icons.wifi,
        label: 'Internet',
        value: utilities.internet,
        valueLabels: const {
          InternetType.included: 'Included',
          InternetType.tenant: 'Tenant',
          InternetType.notAvailable: 'N/A',
        },
      ),
      _UtilityItem(
        icon: Icons.delete_outline,
        label: 'Waste',
        value: utilities.wasteCollection,
        valueLabels: const {
          UtilityResponsibility.tenant: 'Tenant',
          UtilityResponsibility.landlord: 'Landlord',
          UtilityResponsibility.shared: 'Shared',
        },
      ),
      _UtilityItem(
        icon: Icons.security,
        label: 'Security',
        value: utilities.security,
        valueLabels: const {
          SecurityType.included: 'Included',
          SecurityType.notIncluded: 'Not included',
        },
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: items.map((item) => _CompactChip(item: item)).toList(),
      );
    }

    return Column(
      children: items.map((item) => _UtilityRow(item: item)).toList(),
    );
  }
}

class _UtilityItem<T> {
  final IconData icon;
  final String label;
  final T value;
  final Map<T, String> valueLabels;

  _UtilityItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueLabels,
  });
}

class _UtilityRow<T> extends StatelessWidget {
  final _UtilityItem<T> item;

  const _UtilityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valueText = item.valueLabels[item.value] ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.label, style: theme.textTheme.bodyMedium),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _valueColor(item.value, colorScheme).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              valueText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _valueColor(item.value, colorScheme),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactChip<T> extends StatelessWidget {
  final _UtilityItem<T> item;

  const _CompactChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueText = item.valueLabels[item.value] ?? '?';

    return Chip(
      avatar: Icon(item.icon, size: 16, color: colorScheme.primary),
      label: Text(valueText, style: const TextStyle(fontSize: 11)),
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}

Color _valueColor(dynamic value, ColorScheme scheme) {
  return switch (value) {
    UtilityResponsibility.landlord || InternetType.included || SecurityType.included => Colors.green.shade700,
    UtilityResponsibility.shared => Colors.orange.shade700,
    UtilityResponsibility.tenant || InternetType.tenant => scheme.primary,
    InternetType.notAvailable || SecurityType.notIncluded => Colors.grey.shade600,
    _ => scheme.primary,
  };
}
