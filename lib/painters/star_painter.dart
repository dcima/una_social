// lib/painters/star_painter.dart (crea la cartella painters se non esiste)
import 'dart:math';
import 'package:flutter/material.dart';

class StarPainter extends CustomPainter {
  final double radius;
  final double rotation; // In radianti
  final Color color;

  StarPainter({
    required this.radius,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();
    const int numPoints = 5;
    const double innerRadiusRatio = 0.4; // Ratio per i punti interni della stella
    final double outerRadius = radius;
    final double innerRadius = radius * innerRadiusRatio;
    const double angleOffsetToCenter = -pi / 2; // Punta in alto inizialmente

    const double angleStep = 2 * pi / numPoints;
    const double halfAngleStep = angleStep / 2.0;

    // Salva lo stato corrente della canvas
    canvas.save();

    // Trasla al centro della canvas disponibile (size)
    canvas.translate(size.width / 2, size.height / 2);
    // Ruota la canvas
    canvas.rotate(rotation);

    // Calcola i punti e costruisci il path
    path.moveTo(
      outerRadius * cos(angleOffsetToCenter),
      outerRadius * sin(angleOffsetToCenter),
    ); // Primo punto esterno

    for (int i = 0; i < numPoints; i++) {
      // Punto interno
      final double innerAngle = angleOffsetToCenter + halfAngleStep + i * angleStep;
      path.lineTo(
        innerRadius * cos(innerAngle),
        innerRadius * sin(innerAngle),
      );
      // Punto esterno successivo
      final double outerAngle = angleOffsetToCenter + (i + 1) * angleStep;
      path.lineTo(
        outerRadius * cos(outerAngle),
        outerRadius * sin(outerAngle),
      );
    }

    path.close();
    canvas.drawPath(path, paint);

    // Ripristina lo stato originale della canvas (rimuove rotazione e traslazione)
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) {
    return oldDelegate.radius != radius ||
           oldDelegate.rotation != rotation ||
           oldDelegate.color != color;
  }
}