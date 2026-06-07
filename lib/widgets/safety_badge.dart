import 'package:flutter/material.dart';

/// Displays a safety score as a colour-coded badge.
class SafetyBadge extends StatelessWidget {
  final double safetyScore;
  final bool compact;

  const SafetyBadge({
    super.key,
    required this.safetyScore,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = _scoreLabel(safetyScore);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'Safety: ${safetyScore.toStringAsFixed(0)}/100',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

(String label, Color color) _scoreLabel(double score) {
  if (score >= 80) return ('Safe', Colors.green.shade700);
  if (score >= 60) return ('Caution', Colors.orange.shade700);
  if (score >= 40) return ('Risky', Colors.deepOrange.shade700);
  return ('Unsafe', Colors.red.shade700);
}
