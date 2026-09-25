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
  final double pedalAngle;
  final double roadAnimationPhase;

  final int segments = 30;
  final double visualElevationScale = 2.0;

  PerspectiveRoadPainter({
    required this.elevationData,
    required this.currentDistance,
    required this.totalDistance,
    required this.currentGradient,
    required this.currentSpeed,
    required this.cadence,
    required this.pedalAngle,
    required this.roadAnimationPhase,
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

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawMountains(canvas, size);
    _drawRoad(canvas, size);
    _drawCyclist(canvas, size); // 🚀 Рисуем велосипедиста
  }

  void _drawSky(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.6);
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
    final sunY = size.height * 0.15;
    final sunRadius = size.width * 0.04;

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
    final vanishingPointY = size.height * 0.4;
    final baseElevation = _getElevationAt(currentDistance);

    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final layerOffset = layer * 40.0;
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
        height += math.sin((normalizedX * 8) + (distanceOffset * 0.001)) * 25;
        height += math.sin((normalizedX * 4) + (distanceOffset * 0.002)) * 45;
        height += math.sin((normalizedX * 2) + (distanceOffset * 0.0005)) * 70;

        final elevIndex = ((normalizedX * 200) % elevationData.length).floor();
        if (elevationData.isNotEmpty) {
          height += (elevationData[elevIndex] - baseElevation) * 0.15;
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
    final vanishingPointY = size.height * 0.4;
    final baseElevation = _getElevationAt(currentDistance);

    final groundPaint = Paint()
      ..color = const Color(0xFF1a472a)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, vanishingPointY, size.width, size.height * 0.6),
      groundPaint,
    );

    for (int i = 0; i < segments; i++) {
      double t1 = i / segments;
      double t2 = (i + 1) / segments;

      double p1 = math.pow(t1, 2.5).toDouble();
      double p2 = math.pow(t2, 2.5).toDouble();

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

      double width1 = 5.0 + (size.width * 0.5) * p1;
      double width2 = 5.0 + (size.width * 0.5) * p2;

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

        canvas.drawLine(Offset(vanishingPointX - lineWidth1, y1),
            Offset(vanishingPointX - lineWidth2, y2), linePaint);
        canvas.drawLine(Offset(vanishingPointX + lineWidth1, y1),
            Offset(vanishingPointX + lineWidth2, y2), linePaint);
      }

      final edgePaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(vanishingPointX - width1, y1),
          Offset(vanishingPointX - width2, y2), edgePaint);
      canvas.drawLine(Offset(vanishingPointX + width1, y1),
          Offset(vanishingPointX + width2, y2), edgePaint);
    }
  }

  // 🚀 НОВЫЙ МЕТОД: Рисуем силуэт велосипедиста
  void _drawCyclist(Canvas canvas, Size size) {
    // Масштабируем размер велосипедиста относительно высоты экрана
    final double scale = size.height / 500.0;

    // 🚀 МАГИЯ: Покачивание в такт педалированию.
    // sin(pedalAngle) плавно меняется от -1 до 1 при каждом обороте педалей.
    final double bounce = math.sin(pedalAngle) * 4.0 * scale;

    final centerX = size.width / 2;
    final baseY = size.height - (30 * scale); // Базовая позиция снизу

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Рисуем с небольшим смещением bounce по оси Y
    canvas.save();
    canvas.translate(0, bounce);

    // 1. Колёса
    final wheelRadius = 18.0 * scale;
    final rearWheel = Offset(centerX - 35 * scale, baseY);
    final frontWheel = Offset(centerX + 35 * scale, baseY);

    canvas.drawCircle(rearWheel, wheelRadius, paint);
    canvas.drawCircle(frontWheel, wheelRadius, paint);

    // 2. Рама и руль (упрощённый силуэт)
    final framePath = Path();
    framePath.moveTo(centerX - 35 * scale, baseY); // Задняя ось
    framePath.lineTo(
        centerX - 10 * scale, baseY - 35 * scale); // Подседельный штырь
    framePath.lineTo(centerX + 15 * scale, baseY - 35 * scale); // Верхняя труба
    framePath.lineTo(centerX + 35 * scale, baseY); // Передняя вилка
    framePath.lineTo(centerX + 5 * scale, baseY - 10 * scale); // Каретка
    framePath.close();
    canvas.drawPath(framePath, paint);

    // 3. Седло и руль
    final seatPath = Path();
    seatPath.moveTo(centerX - 15 * scale, baseY - 38 * scale);
    seatPath.lineTo(centerX - 5 * scale, baseY - 38 * scale);
    seatPath.lineTo(centerX - 5 * scale, baseY - 35 * scale);
    seatPath.close();
    canvas.drawPath(seatPath, paint);

    final handlebarPath = Path();
    handlebarPath.moveTo(centerX + 15 * scale, baseY - 35 * scale);
    handlebarPath.lineTo(centerX + 25 * scale, baseY - 40 * scale);
    handlebarPath.lineTo(centerX + 28 * scale, baseY - 38 * scale);
    handlebarPath.close();
    canvas.drawPath(handlebarPath, paint);

    // 4. Силуэт гонщика (голова и торс)
    final riderPath = Path();
    // Голова
    riderPath.addOval(Rect.fromCircle(
        center: Offset(centerX + 5 * scale, baseY - 55 * scale),
        radius: 7 * scale));
    // Торс и руки (аэропосадка)
    riderPath.moveTo(centerX + 5 * scale, baseY - 48 * scale);
    riderPath.lineTo(centerX - 5 * scale, baseY - 38 * scale); // Спина к седлу
    riderPath.lineTo(centerX + 25 * scale, baseY - 40 * scale); // Руки к рулю
    riderPath.lineTo(
        centerX + 15 * scale, baseY - 35 * scale); // Возврат к раме
    riderPath.close();
    canvas.drawPath(riderPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PerspectiveRoadPainter oldDelegate) {
    return oldDelegate.currentDistance != currentDistance ||
        oldDelegate.currentGradient != currentGradient ||
        oldDelegate.pedalAngle !=
            pedalAngle || // Важно для анимации велосипедиста!
        oldDelegate.roadAnimationPhase != roadAnimationPhase;
  }
}
