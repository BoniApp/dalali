import 'package:flutter/material.dart';
import 'package:dalali/models/user_model.dart';

class VerificationBadge extends StatelessWidget {
  final VerificationStatus status;
  final double size;

  const VerificationBadge({super.key, required this.status, this.size = 16});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case VerificationStatus.verified:
        return Tooltip(
          message: 'Verified',
          child: Icon(Icons.verified, color: Colors.green, size: size),
        );
      case VerificationStatus.pending:
        return Tooltip(
          message: 'Verification Pending',
          child: Icon(Icons.pending, color: Colors.orange, size: size),
        );
      case VerificationStatus.unverified:
        return Tooltip(
          message: 'Not Verified',
          child: Icon(Icons.warning_amber, color: Colors.grey, size: size),
        );
    }
  }
}
