import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// IQC FEEDBACK BADGE
/// ═══════════════════════════════════════════════════════════════
///
/// Real-time image quality feedback widget.
/// Shows blur, glare, and face detection status.
///
class IqcFeedbackBadge extends StatelessWidget {
  final double blurScore;
  final double glareScore;
  final bool hasFace;

  const IqcFeedbackBadge({
    super.key,
    required this.blurScore,
    required this.glareScore,
    required this.hasFace,
  });

  bool get isBlurOk => blurScore > 500;
  bool get isGlareOk => glareScore < 0.20;
  bool get allOk => isBlurOk && isGlareOk && hasFace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: allOk ? Colors.green.shade800 : Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            allOk ? Icons.check_circle : Icons.warning_amber,
            color: allOk ? Colors.green.shade200 : Colors.orange.shade200,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            allOk ? 'Good quality' : _issueText,
            style: TextStyle(
              color: allOk ? Colors.green.shade100 : Colors.orange.shade100,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String get _issueText {
    if (!hasFace) return 'No face detected';
    if (!isBlurOk) return 'Too blurry — hold steady';
    if (!isGlareOk) return 'Too much glare — tilt away from light';
    return 'Adjust document';
  }
}
