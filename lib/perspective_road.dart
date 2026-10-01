// lib/perspective_road.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class PerspectiveRoadPainter extends CustomPainter {
  final List<double> elevationData;
  final double currentDistance;
  final double totalDistance;
  final double currentGradient;
  final double currentSpeed;
  final double cadence;
  final double roadAnimationPhase;
  final List<double> curveData;

  final int segments = 60; // Увеличили количество сегментов для плавности
  final double visualElevationScale = 5.0; // Усилили эффект рельефа

  PerspectiveRoadPainter({
    required this.elevationData,
    required this.currentDistance,
    required this.totalDistance,
    required this.currentGradient,
    required this.currentSpeed,
    required this.cadence,
    required this.roadAnimationPhase,
    required this.curveData,
  });

  double _getElevationAt(double distance) {
    if (elevationData.isEmpty) return 0.0;
    double normalizedIndex =
        (distance / totalDistance) * (elevationData.length - 1);
    normalizedIndex = normalizedIndex.clamp(0.0, elevationData.length - 1.0);

    int index1 = normalizedIndex.floor();
    int index2 = (index1 + 1).clamp(0, elevationData.length - 1);
    double fraction = normalizedIndex - index1;

    return elevationData[index1] +
        (elevationData[index2] - elevationData[index1]) * fraction;
  }

  double _getCurveAt(double distance) {
  if (curveData.isEmpty) return 0.0;
  double normalizedIndex = (distance / totalDistance) * (curveData.length - 1);
  normalizedIndex = normalizedIndex.clamp(0.0, curveData.length - 1.0);

  int index1 = normalizedIndex.floor();
  int index2 = (index1 + 1).clamp(0, curveData.length - 1);
  double fraction = normalizedIndex - index1;

  return curveData[index1] + (curveData[index2] - curveData[index1]) * fraction;
}

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawMountains(canvas, size);
    _drawRoad(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    // 🚀 Точка схода сильно поднята (камера смотрит вниз)
    final vanishingPointY = size.height * 0.4; // Было 0.4, стало 0.22
    final skyRect = Rect.fromLTWH(0, 0, size.width, vanishingPointY);
    
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF0F2027),
        Color(0xFF203A43),
        Color(0xFF2C5364),
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(skyRect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(skyRect, paint);
    _drawCelestialBody(canvas, size);
  }

  void _drawCelestialBody(Canvas canvas, Size size) {
    final sunX = size.width * 0.8;
    final sunY = size.height * 0.1;
    final sunRadius = size.width * 0.035;

    final sunPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(Offset(sunX, sunY), sunRadius, sunPaint);

    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

    canvas.drawCircle(Offset(sunX, sunY), sunRadius * 2.5, glowPaint);
  }

  void _drawMountains(Canvas canvas, Size size) {
    final vanishingPointY = size.height * 0.22;
    final baseElevation = _getElevationAt(currentDistance);

    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final layerOffset = layer * 30.0;
      final mountainColor = [
        const Color(0xFF1a1a2e),
        const Color(0xFF16213e),
        const Color(0xFF0f3460),
      ][layer];

      path.moveTo(0, vanishingPointY);

      final distanceOffset = currentDistance * (2.0 + layer * 1.5);

      for (double x = 0; x <= size.width; x += 5) {
        final normalizedX = x / size.width;

        double height = 0;
        height += math.sin((normalizedX * 8) + (distanceOffset * 0.001)) * 20;
        height += math.sin((normalizedX * 4) + (distanceOffset * 0.002)) * 35;
        height += math.sin((normalizedX * 2) + (distanceOffset * 0.0005)) * 50;

        final elevIndex = ((normalizedX * 200) % elevationData.length).floor();
        if (elevationData.isNotEmpty) {
          height += (elevationData[elevIndex] - baseElevation) * 0.1;
        }

        final y = vanishingPointY - height - layerOffset;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      final paint = Paint()
        ..color = mountainColor.withOpacity(0.85 - (layer * 0.2))
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);
    }
  }

  void _drawRoad(Canvas canvas, Size size) {
    final vanishingPointX = size.width / 2;
    final vanishingPointY = size.height * 0.22; // 🚀 Точка схода поднята
    final baseElevation = _getElevationAt(currentDistance);

    final groundPaint = Paint()
      ..color = const Color(0xFF1a472a)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, vanishingPointY, size.width, size.height - vanishingPointY),
      groundPaint,
    );

    // 🚀 РЕЗКО УСИЛЕННАЯ ПЕРСПЕКТИВА для вида сверху
    // Было 2.5, стало 4.0 — ближние сегменты огромные, дальние крошечные
    const double perspectivePower = 4.0;

    for (int i = 0; i < segments; i++) {
      double t1 = i / segments;
      double t2 = (i + 1) / segments;

      double p1 = math.pow(t1, perspectivePower).toDouble();
      double p2 = math.pow(t2, perspectivePower).toDouble();

      double y1Base = vanishingPointY + (size.height - vanishingPointY) * p1;
      double y2Base = vanishingPointY + (size.height - vanishingPointY) * p2;

      double lookAheadMax = 100.0;
      double dist1 = currentDistance + (t1 * lookAheadMax);
      double dist2 = currentDistance + (t2 * lookAheadMax);

      double elev1 = _getElevationAt(dist1) - baseElevation;
      double elev2 = _getElevationAt(dist2) - baseElevation;

      double yShift1 = -elev1 * visualElevationScale;
      double yShift2 = -elev2 * visualElevationScale;

      double y1 = y1Base + yShift1;
      double y2 = y2Base + yShift2;

      double curve1 = _getCurveAt(dist1);
      double curve2 = _getCurveAt(dist2);
      double maxShift = size.width * 0.35;

      //  ДОРОГА ОЧЕНЬ ШИРОКАЯ ВНИЗУ (эффект взгляда сверху)
      // Начальная ширина 20 (было 5), коэффициент 0.6 (было 0.5)
      const double roadStartWidth = 20.0;
      const double roadWidthFactor = 0.6;

      double centerX1 = vanishingPointX + curve1 * maxShift;
      double centerX2 = vanishingPointX + curve2 * maxShift;
      
      double width1 = roadStartWidth + (size.width * roadWidthFactor) * p1;
      double width2 = roadStartWidth + (size.width * roadWidthFactor) * p2;

      final path = Path();
      path.moveTo(vanishingPointX - width1, y1);
      path.lineTo(vanishingPointX + width1, y1);
      path.lineTo(vanishingPointX + width2, y2);
      path.lineTo(vanishingPointX - width2, y2);
      path.close();

      final double segmentValue = i + (roadAnimationPhase * 2.0);
      final bool isDark = (segmentValue % 2.0) < 1.0;

      final paint = Paint()
        ..color = isDark ? const Color(0xFF374151) : const Color(0xFF4B5563)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      if (isDark) {
        final linePaint = Paint()
          ..color = Colors.yellow.withOpacity(0.9)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

        final lineWidth1 = width1 * 0.05;
        final lineWidth2 = width2 * 0.05;

        canvas.drawLine(Offset(centerX1 - lineWidth1, y1),
            Offset(centerX2 - lineWidth2, y2), linePaint);
        canvas.drawLine(Offset(centerX1 + lineWidth1, y1),
            Offset(centerX2 + lineWidth2, y2), linePaint);
      }

      final edgePaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(centerX1 - width1, y1),
          Offset(centerX2 - width2, y2), edgePaint);
      canvas.drawLine(Offset(centerX1 + width1, y1),
          Offset(centerX2 + width2, y2), edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PerspectiveRoadPainter oldDelegate) {
    return oldDelegate.currentDistance != currentDistance ||
        oldDelegate.currentGradient != currentGradient ||
        oldDelegate.roadAnimationPhase != roadAnimationPhase;
  }
}