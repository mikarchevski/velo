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
    final vanishingPointY = size.height * 0.22;
    final baseElevation = _getElevationAt(currentDistance);

    // 1. Рисуем землю (фон)
    canvas.drawRect(
      Rect.fromLTWH(0, vanishingPointY, size.width, size.height - vanishingPointY),
      Paint()..color = const Color(0xFF1a472a)..style = PaintingStyle.fill,
    );

    const double perspectivePower = 4.0;
    
    // 🚀 УВЕЛИЧИЛИ МАКСИМАЛЬНЫЙ СДВИГ ДО 50% ШИРИНЫ ЭКРАНА
    // Это сделает поворот гипертрофированно заметным для проверки
    final double maxShift = size.width * 0.5; 

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

      double y1 = y1Base - elev1 * visualElevationScale;
      double y2 = y2Base - elev2 * visualElevationScale;

      // 🚀 ПОЛУЧАЕМ ЗНАЧЕНИЕ ПОВОРОТА (-1.0 до 1.0)
      double curve1 = _getCurveAt(dist1);
      double curve2 = _getCurveAt(dist2);

      // 🚀 ВЫЧИСЛЯЕМ РЕАЛЬНЫЙ ЦЕНТР ДОРОГИ С УЧЁТОМ ИЗГИБА
      double centerX1 = vanishingPointX + (curve1 * maxShift);
      double centerX2 = vanishingPointX + (curve2 * maxShift);

      // Отладочный вывод для первого сегмента, чтобы доказать смещение
      if (i == 0 && curve1.abs() > 0.1) {
        print("🛣️ ИЗГИБ: centerX1 сдвинут на ${(curve1 * maxShift).toStringAsFixed(1)} пикселей (curve=$curve1)");
      }

      // Ширина дороги
      const double roadStartWidth = 20.0;
      const double roadWidthFactor = 0.6;
      double width1 = roadStartWidth + (size.width * roadWidthFactor) * p1;
      double width2 = roadStartWidth + (size.width * roadWidthFactor) * p2;

      // 🚀 РИСУЕМ АСФАЛЬТ (ТРАПЕЦИЯ)
      final path = Path();
      path.moveTo(centerX1 - width1, y1); // Левый верхний угол
      path.lineTo(centerX1 + width1, y1); // Правый верхний угол
      path.lineTo(centerX2 + width2, y2); // Правый нижний угол
      path.lineTo(centerX2 - width2, y2); // Левый нижний угол
      path.close();

      final bool isDark = ((i + (roadAnimationPhase * 2.0)) % 2.0) < 1.0;

      // Рисуем саму дорогу (асфальт)
      canvas.drawPath(
        path,
        Paint()
          ..color = isDark ? const Color(0xFF374151) : const Color(0xFF4B5563)
          ..style = PaintingStyle.fill,
      );

      // 🚀 РИСУЕМ РАЗМЕТКУ (строго по тем же координатам центра!)
      if (isDark) {
        final linePaint = Paint()
          ..color = Colors.yellow.withOpacity(0.9)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;

        final lineWidth1 = width1 * 0.04;
        final lineWidth2 = width2 * 0.04;

        // Левая пунктирная линия
        canvas.drawLine(Offset(centerX1 - lineWidth1, y1), Offset(centerX2 - lineWidth2, y2), linePaint);
        // Правая пунктирная линия
        canvas.drawLine(Offset(centerX1 + lineWidth1, y1), Offset(centerX2 + lineWidth2, y2), linePaint);
      }

      // 🚀 РИСУЕМ БЕЛЫЕ КРАЯ (строго по краям трапеции!)
      final edgePaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(centerX1 - width1, y1), Offset(centerX2 - width2, y2), edgePaint);
      canvas.drawLine(Offset(centerX1 + width1, y1), Offset(centerX2 + width2, y2), edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PerspectiveRoadPainter oldDelegate) {
    return oldDelegate.currentDistance != currentDistance ||
        oldDelegate.currentGradient != currentGradient ||
        oldDelegate.roadAnimationPhase != roadAnimationPhase;
  }
}