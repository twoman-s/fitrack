import 'dart:math';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Lightweight framing guide overlay for the camera preview.
///
/// Draws:
/// - Center vertical guide line
/// - Head alignment marker near the top
/// - Feet alignment marker near the bottom
/// - Optional shoulder-width zone markers
/// - Distance instruction text at the bottom
class CameraGuideOverlay extends StatelessWidget {
  final String photoType;

  const CameraGuideOverlay({super.key, required this.photoType});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _GuidePainter(photoType: photoType),
            ),
            // Instruction labels
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Align top of head',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Keep feet near this line',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GuidePainter extends CustomPainter {
  final String photoType;

  _GuidePainter({required this.photoType});

  @override
  void paint(Canvas canvas, Size size) {
    // We draw lines twice to create a high-contrast outline effect.
    // 1. Dark shadow background
    final shadowGuidePaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final shadowMarkerPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final shadowShoulderPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 2.5;

    // 2. Light foreground (using primary theme color)
    final guidePaint = Paint()
      ..color = Colors.red.withOpacity(0.9)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final markerPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final shoulderPaint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..strokeWidth = 1.0;

    final centerX = size.width / 2;
    final markerWidth = size.width * 0.12;

    void drawAll(Paint gPaint, Paint mPaint, Paint sPaint) {
      // ── Center vertical guide line ──────────────────────────────────────
      _drawDashedLine(
        canvas,
        Offset(centerX, 0),
        Offset(centerX, size.height),
        gPaint,
        dashLength: 8,
        gapLength: 6,
      );

      // ── Head marker (horizontal line at very top) ─────────────────────────
      final headY = 2.0; // Near top edge
      canvas.drawLine(
        Offset(centerX - markerWidth, headY),
        Offset(centerX + markerWidth, headY),
        mPaint,
      );
      // Small tick marks
      canvas.drawLine(
        Offset(centerX - markerWidth, headY - 4),
        Offset(centerX - markerWidth, headY + 4),
        mPaint,
      );
      canvas.drawLine(
        Offset(centerX + markerWidth, headY - 4),
        Offset(centerX + markerWidth, headY + 4),
        mPaint,
      );

      // ── Feet marker (horizontal line at very bottom) ──────────────────────
      final feetY = size.height - 2.0; // Near bottom edge
      canvas.drawLine(
        Offset(centerX - markerWidth, feetY),
        Offset(centerX + markerWidth, feetY),
        mPaint,
      );
      canvas.drawLine(
        Offset(centerX - markerWidth, feetY - 4),
        Offset(centerX - markerWidth, feetY + 4),
        mPaint,
      );
      canvas.drawLine(
        Offset(centerX + markerWidth, feetY - 4),
        Offset(centerX + markerWidth, feetY + 4),
        mPaint,
      );

      // ── Shoulder-width zone (soft side boundaries) ─────────────────────
      final shoulderInset = size.width * 0.20;
      final shoulderTop = 0.0;
      final shoulderBottom = size.height;

      // Left boundary
      _drawDashedLine(
        canvas,
        Offset(shoulderInset, shoulderTop),
        Offset(shoulderInset, shoulderBottom),
        sPaint,
        dashLength: 4,
        gapLength: 8,
      );
      // Right boundary
      _drawDashedLine(
        canvas,
        Offset(size.width - shoulderInset, shoulderTop),
        Offset(size.width - shoulderInset, shoulderBottom),
        sPaint,
        dashLength: 4,
        gapLength: 8,
      );
    }

    // Draw shadow layer first
    drawAll(shadowGuidePaint, shadowMarkerPaint, shadowShoulderPaint);
    // Draw foreground layer
    drawAll(guidePaint, markerPaint, shoulderPaint);

  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashLength = 5,
    double gapLength = 5,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLength = (dx * dx + dy * dy);
    final sqrtDist = sqrt(totalLength);
    if (sqrtDist <= 0) return;
    final unitX = dx / sqrtDist;
    final unitY = dy / sqrtDist;

    double drawn = 0;
    bool drawing = true;
    while (drawn < sqrtDist) {
      final segLen = drawing ? dashLength : gapLength;
      final remaining = sqrtDist - drawn;
      final len = segLen < remaining ? segLen : remaining;

      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + unitX * drawn, start.dy + unitY * drawn),
          Offset(start.dx + unitX * (drawn + len), start.dy + unitY * (drawn + len)),
          paint,
        );
      }
      drawn += len;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) => old.photoType != photoType;
}
