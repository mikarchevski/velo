// lib/cyclist_legs_painter.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class CyclistLegsPainter extends CustomPainter {
  final double pedalAngle; // Приходит из main.dart

  CyclistLegsPainter({required this.pedalAngle});

  @override
  void paint(Canvas canvas, Size size) {
    // Масштабируем под размер виджета (140x168 в main.dart)
    // Базовые координаты из SVG (100x120) умножаем на 1.4
    final double scale = size.width / 100.0;

    // Точки бедер (под шортами)
    final Offset hipLeft = Offset(42 * scale, 78 * scale);
    final Offset hipRight = Offset(58 * scale, 78 * scale);

    // Центр каретки (где крутятся педали)
    final Offset bottomBracket = Offset(50 * scale, 95 * scale);
    final double crankLength = 14 * scale; // Длина шатуна

    // --- ЛЕВАЯ НОГА ---
    // Стопа описывает круг. sin/cos дают движение по кругу.
    final double leftFootX =
        bottomBracket.dx + crankLength * math.sin(pedalAngle);
    final double leftFootY =
        bottomBracket.dy - crankLength * math.cos(pedalAngle);

    // --- ПРАВАЯ НОГА (сдвинута на 180 градусов / PI) ---
    final double rightFootX =
        bottomBracket.dx + crankLength * math.sin(pedalAngle + math.pi);
    final double rightFootY =
        bottomBracket.dy - crankLength * math.cos(pedalAngle + math.pi);

    final legPaint = Paint()
      ..color = const Color(0xFFd4a574) // Цвет кожи
      ..strokeWidth = 6 * scale // Толщина ноги
      ..strokeCap = StrokeCap.round // Закругленные края (колени и стопы)
      ..style = PaintingStyle.stroke;

    // Рисуем левую ногу с легким изгибом в колене (квадратичная кривая)
    final leftLegPath = Path();
    leftLegPath.moveTo(hipLeft.dx, hipLeft.dy);
    // Контрольная точка слегка смещена наружу, имитируя изгиб колена
    final leftKneeX = (hipLeft.dx + leftFootX) / 2 - (3 * scale);
    final leftKneeY = (hipLeft.dy + leftFootY) / 2;
    leftLegPath.quadraticBezierTo(leftKneeX, leftKneeY, leftFootX, leftFootY);
    canvas.drawPath(leftLegPath, legPaint);

    // Рисуем правую ногу
    final rightLegPath = Path();
    rightLegPath.moveTo(hipRight.dx, hipRight.dy);
    final rightKneeX = (hipRight.dx + rightFootX) / 2 + (3 * scale);
    final rightKneeY = (hipRight.dy + rightFootY) / 2;
    rightLegPath.quadraticBezierTo(
        rightKneeX, rightKneeY, rightFootX, rightFootY);
    canvas.drawPath(rightLegPath, legPaint);
  }

  @override
  bool shouldRepaint(covariant CyclistLegsPainter oldDelegate) {
    return oldDelegate.pedalAngle != pedalAngle;
  }
}
