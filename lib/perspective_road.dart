import 'package:flutter/material.dart';

import 'dart:math' as math;

class PerspectiveRoadPainter extends CustomPainter {
  final List<double> elevationData;
  final double currentDistance;
  final double totalDistance;
  final double currentSpeed;
  final double cadence;
  final double pedalAngle;

  PerspectiveRoadPainter({
    required this.elevationData,
    required this.currentDistance,
    required this.totalDistance,
    required this.currentSpeed,
    required this.cadence,
    required this.pedalAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elevationData.isEmpty) return;

    final vanishingPointX = size.width / 2;
    final vanishingPointY = size.height * 0.4;

    // Рисуем небо
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF1E88E5), const Color(0xFF64B5F6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, vanishingPointY));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, vanishingPointY), skyPaint);

    // Рисуем траву
    final grassPaint = Paint()..color = const Color(0xFF4CAF50);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        vanishingPointY,
        size.width,
        size.height - vanishingPointY,
      ),
      grassPaint,
    );

    // Рисуем дорогу
    _drawRoad(canvas, size, vanishingPointX, vanishingPointY);

    // Рисуем велосипедиста
    _drawCyclist(canvas, size);
  }

  void _drawRoad(
    Canvas canvas,
    Size size,
    double vanishingPointX,
    double vanishingPointY,
  ) {
    final roadPath = Path();
    final roadWidthBottom = size.width * 0.8; // Ширина дороги внизу
    final roadWidthHorizon = 20.0; // Ширина дороги на горизонте

    // Левый край дороги
    roadPath.moveTo(vanishingPointX - roadWidthHorizon, vanishingPointY);
    roadPath.lineTo(vanishingPointX - roadWidthBottom, size.height);

    // Правый край дороги
    roadPath.lineTo(vanishingPointX + roadWidthBottom, size.height);
    roadPath.lineTo(vanishingPointX + roadWidthHorizon, vanishingPointY);
    roadPath.close();

    // Асфальт
    final roadPaint = Paint()
      ..color = const Color(0xFF424242)
      ..style = PaintingStyle.fill;
    canvas.drawPath(roadPath, roadPaint);

    // Разделительная полоса (пунктирная)
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Анимация движения разметки
    final animationOffset = (currentDistance * 50) % 100;

    for (double i = animationOffset; i < size.height; i += 100) {
      // Интерполяция позиции и ширины
      final progress = (i - vanishingPointY) / (size.height - vanishingPointY);
      if (progress < 0) continue;

      final x = vanishingPointX;
      final y = vanishingPointY + (size.height - vanishingPointY) * progress;
      final lineWidth = 20 * progress;

      canvas.drawLine(
        Offset(x - lineWidth, y),
        Offset(x + lineWidth, y),
        linePaint,
      );
    }

    // Обочины (белые линии)
    final edgePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(vanishingPointX - roadWidthHorizon, vanishingPointY),
      Offset(vanishingPointX - roadWidthBottom, size.height),
      edgePaint,
    );
    canvas.drawLine(
      Offset(vanishingPointX + roadWidthHorizon, vanishingPointY),
      Offset(vanishingPointX + roadWidthBottom, size.height),
      edgePaint,
    );
  }

  void _drawCyclist(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final bottomY = size.height - 50;

    // Тень от велосипедиста
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, bottomY + 10),
        width: 60,
        height: 15,
      ),
      shadowPaint,
    );

    // Велосипед (вид сзади)
    final bikePaint = Paint()
      ..color = const Color(0xFF00BCD4)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    // Рама велосипеда (вид сзади - две стойки)
    canvas.drawLine(
      Offset(centerX - 15, bottomY - 30),
      Offset(centerX - 15, bottomY + 10),
      bikePaint,
    );
    canvas.drawLine(
      Offset(centerX + 15, bottomY - 30),
      Offset(centerX + 15, bottomY + 10),
      bikePaint,
    );
    canvas.drawLine(
      Offset(centerX - 15, bottomY - 30),
      Offset(centerX + 15, bottomY - 30),
      bikePaint,
    );

    // Заднее колесо (одно, по центру)
    // Заднее колесо (вид сзади - узкий овал)
    final wheelPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Рисуем колесо как узкий вертикальный эллипс (вид сзади)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, bottomY), width: 12, height: 40),
      wheelPaint,
    );

    // Спицы колеса (для эффекта вращения)
    final spokePaint = Paint()
      ..color = const Color(0xFF757575)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Анимация вращения колеса на основе скорости
    final wheelRotation = (currentDistance * 10) % (2 * math.pi);

    // Рисуем несколько спиц
    for (int i = 0; i < 4; i++) {
      final angle = wheelRotation + (i * math.pi / 2);
      final x1 = centerX + math.cos(angle) * 6;
      final y1 = bottomY + math.sin(angle) * 20;
      final x2 = centerX + math.cos(angle + math.pi) * 6;
      final y2 = bottomY + math.sin(angle + math.pi) * 20;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), spokePaint);
    }

    // Велосипедист (тело)
    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, bottomY - 50),
        width: 50,
        height: 60,
      ),
      bodyPaint,
    );

    // Голова
    final headPaint = Paint()..color = const Color(0xFFFFCC80);
    canvas.drawCircle(Offset(centerX, bottomY - 85), 18, headPaint);

    // Шлем
    final helmetPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX, bottomY - 90),
        width: 38,
        height: 25,
      ),
      math.pi,
      math.pi,
      true,
      helmetPaint,
    );

    // Руки (держат руль)
    final armPaint = Paint()
      ..color = const Color(0xFFFFCC80)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX - 15, bottomY - 60),
      Offset(centerX - 25, bottomY - 45),
      armPaint,
    );
    canvas.drawLine(
      Offset(centerX + 15, bottomY - 60),
      Offset(centerX + 25, bottomY - 45),
      armPaint,
    );

    // НОГИ С ВРАЩЕНИЕМ (вид сзади)
    // НОГИ С ВРАЩЕНИЕМ (вид строго сзади)
    // НОГИ С ВРАЩЕНИЕМ (вид строго со спины - только вертикальное движение)
    // НОГИ С ВРАЩЕНИЕМ (вид строго со спины - только вертикальное движение)
    final legPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Центр каретки (опустили ближе к колесу)
    final crankCenterX = centerX;
    final crankCenterY = bottomY - 5; // Было -15, теперь -5 (ближе к земле)
    final crankRadius = 20.0;

    // Бёдра (тоже опустили, чтобы ноги не были слишком длинными)
    final rightHipX = centerX + 10;
    final rightHipY = bottomY - 25; // Было -35, теперь -25

    final leftHipX = centerX - 10;
    final leftHipY = bottomY - 25;

    // Педали двигаются ТОЛЬКО ВВЕРХ-ВНИЗ
    // Правая педаль
    final rightPedalX = centerX + 10;
    final rightPedalY = crankCenterY + math.cos(pedalAngle) * crankRadius;

    // Левая педаль (сдвиг на 180°)
    final leftPedalX = centerX - 10;
    final leftPedalY =
        crankCenterY + math.cos(pedalAngle + math.pi) * crankRadius;

    // Функция для рисования ноги
    void drawLeg(double hipX, double hipY, double pedalX, double pedalY) {
      double midX = (hipX + pedalX) / 2;
      double midY = (hipY + pedalY) / 2;

      double kneeX = midX;
      double kneeY = midY + 5;

      canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, kneeY), legPaint);
      canvas.drawLine(Offset(kneeX, kneeY), Offset(pedalX, pedalY), legPaint);
    }

    // Рисуем обе ноги
    drawLeg(rightHipX, rightHipY, rightPedalX, rightPedalY);
    drawLeg(leftHipX, leftHipY, leftPedalX, leftPedalY);

    // Педали
    final pedalPaint = Paint()..color = const Color(0xFF757575);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(rightPedalX, rightPedalY),
        width: 12,
        height: 6,
      ),
      pedalPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(leftPedalX, leftPedalY),
        width: 12,
        height: 6,
      ),
      pedalPaint,
    );

    // Каретка (рисуем ПОСЛЕ ног, чтобы перекрывала их)
    final crankPaint = Paint()..color = const Color(0xFF424242);
    canvas.drawCircle(Offset(crankCenterX, crankCenterY), 8, crankPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
