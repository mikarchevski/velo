// lib/cyclist_legs_painter.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class CyclistLegsPainter extends CustomPainter {
  final double pedalAngle;

  CyclistLegsPainter({required this.pedalAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 100.0;

    // Точки бёдер (чуть уже для реалистичной стойки)
    final Offset hipLeft = Offset(44 * scale, 78 * scale);
    final Offset hipRight = Offset(56 * scale, 78 * scale);

    // Центр каретки
    final Offset bottomBracket = Offset(50 * scale, 95 * scale);
    final double crankLength = 14 * scale;

    // --- СТОПЫ (движутся почти строго вертикально) ---
    // Минимальное смещение по X (ширина стойки Q-factor)
    final double leftFootX = bottomBracket.dx - (5 * scale);
    final double leftFootY = bottomBracket.dy - crankLength * math.cos(pedalAngle);

    final double rightFootX = bottomBracket.dx + (5 * scale);
    final double rightFootY = bottomBracket.dy - crankLength * math.cos(pedalAngle + math.pi);

    // Определяем, какая нога сзади (дальше от зрителя), чтобы нарисовать её первой и тоньше
    final bool leftLegBehind = math.cos(pedalAngle) < 0;

    if (leftLegBehind) {
      _drawLeg(canvas, hipLeft, leftFootX, leftFootY, scale, isBehind: true);
      _drawLeg(canvas, hipRight, rightFootX, rightFootY, scale, isBehind: false);
    } else {
      _drawLeg(canvas, hipRight, rightFootX, rightFootY, scale, isBehind: true);
      _drawLeg(canvas, hipLeft, leftFootX, leftFootY, scale, isBehind: false);
    }
  }

  void _drawLeg(Canvas canvas, Offset hip, double footX, double footY, 
      double scale, {required bool isBehind}) {
    
    // Задняя нога чуть тоньше для эффекта перспективы
    final double strokeWidth = isBehind ? 4.5 * scale : 6.0 * scale;
    
    final legPaint = Paint()
      ..color = const Color(0xFFd4a574) // Цвет кожи
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Вычисляем текущее расстояние от бедра до стопы
    final double currentDist = math.sqrt(
      math.pow(footX - hip.dx, 2) + math.pow(footY - hip.dy, 2)
    );

    // Максимальная длина выпрямленной ноги (бедро до нижней точки педали)
    // 78 (бедро) до 95+14 (низ педали) = 31 * scale
    final double maxStraightDist = 31.0 * scale;
    
    // Насколько нога согнута: чем меньше расстояние, тем сильнее сгиб
    final double bendAmount = (maxStraightDist - currentDist).clamp(0.0, 12.0 * scale);

    // Колено по горизонтали всегда строго между бедром и стопой (никаких взмахов в сторону!)
    // Добавляем крошечный сдвиг (1 * scale) наружу для естественности стойки
    final double direction = hip.dx < 50 * scale ? -1.0 : 1.0;
    final double kneeX = (hip.dx + footX) / 2 + (1.0 * scale * direction);
    
    // По вертикали колено "поднимается" вверх, когда нога сгибается (имитация сгиба вперёд)
    final double kneeY = (hip.dy + footY) / 2 - (bendAmount * 0.6);

    // Рисуем ногу
    final legPath = Path();
    legPath.moveTo(hip.dx, hip.dy);
    legPath.quadraticBezierTo(kneeX, kneeY, footX, footY);
    canvas.drawPath(legPath, legPaint);
    
    // Аккуратный акцент на колене (только когда нога заметно согнута)
    if (bendAmount > 4.0 * scale) {
      final kneePaint = Paint()
        ..color = const Color(0xFFc99564) // Чуть темнее
        ..strokeWidth = strokeWidth * 0.8
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(kneeX, kneeY), strokeWidth * 0.5, kneePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyclistLegsPainter oldDelegate) {
    return oldDelegate.pedalAngle != pedalAngle;
  }
}