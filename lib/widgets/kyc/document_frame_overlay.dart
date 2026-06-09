import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// DOCUMENT FRAME OVERLAY
/// ═══════════════════════════════════════════════════════════════
///
/// Painted overlay that guides the user to position their ID
/// document correctly within the camera preview.
///
class DocumentFrameOverlay extends StatelessWidget {
  final double cornerRadius;
  final double strokeWidth;
  final Color borderColor;

  const DocumentFrameOverlay({
    super.key,
    this.cornerRadius = 16,
    this.strokeWidth = 3,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _DocumentFramePainter(
        cornerRadius: cornerRadius,
        strokeWidth: strokeWidth,
        borderColor: borderColor,
      ),
    );
  }
}

class _DocumentFramePainter extends CustomPainter {
  final double cornerRadius;
  final double strokeWidth;
  final Color borderColor;

  _DocumentFramePainter({
    required this.cornerRadius,
    required this.strokeWidth,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.85,
      height: size.height * 0.55,
    );

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));
    canvas.drawRRect(rrect, paint);

    // Corner accents
    final accentPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth * 1.5
      ..style = PaintingStyle.stroke;

    final cornerLength = cornerRadius * 1.5;

    // Top-left
    canvas.drawLine(
      rect.topLeft + Offset(0, cornerLength),
      rect.topLeft,
      accentPaint,
    );
    canvas.drawLine(
      rect.topLeft + Offset(cornerLength, 0),
      rect.topLeft,
      accentPaint,
    );

    // Top-right
    canvas.drawLine(
      rect.topRight + Offset(0, cornerLength),
      rect.topRight,
      accentPaint,
    );
    canvas.drawLine(
      rect.topRight + Offset(-cornerLength, 0),
      rect.topRight,
      accentPaint,
    );

    // Bottom-left
    canvas.drawLine(
      rect.bottomLeft + Offset(0, -cornerLength),
      rect.bottomLeft,
      accentPaint,
    );
    canvas.drawLine(
      rect.bottomLeft + Offset(cornerLength, 0),
      rect.bottomLeft,
      accentPaint,
    );

    // Bottom-right
    canvas.drawLine(
      rect.bottomRight + Offset(0, -cornerLength),
      rect.bottomRight,
      accentPaint,
    );
    canvas.drawLine(
      rect.bottomRight + Offset(-cornerLength, 0),
      rect.bottomRight,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
