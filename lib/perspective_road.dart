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

    // Рисуем рельеф (силуэт холмов на горизонте)
    _drawTerrain(canvas, size, vanishingPointX, vanishingPointY);

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

  void _drawTerrain(
    Canvas canvas,
    Size size,
    double vanishingPointX,
    double vanishingPointY,
  ) {
    if (elevationData.isEmpty) return;

    // Находим мин/макс высоту для масштабирования
    double minElev = elevationData.reduce((a, b) => a < b ? a : b);
    double maxElev = elevationData.reduce((a, b) => a > b ? a : b);
    double elevRange = maxElev - minElev;
    if (elevRange == 0) elevRange = 1;

    // Показываем участок трассы вокруг текущей позиции
    double viewRange = totalDistance * 0.3; // Показываем 30% трассы

    if (viewRange < 100) viewRange = 100;

    double screenStartDistance = currentDistance - viewRange;
    double screenEndDistance = currentDistance + viewRange * 2;

    // Рисуем силуэт рельефа
    final terrainPath = Path();
    bool isFirstPoint = true;

    for (int i = 0; i < elevationData.length; i++) {
      double pointDistance = (i / elevationData.length) * totalDistance;

      if (pointDistance >= screenStartDistance &&
          pointDistance <= screenEndDistance) {
        double x = ((pointDistance - screenStartDistance) /
                (screenEndDistance - screenStartDistance)) *
            size.width;

        // Масштабируем высоту: максимум 60 пикселей выше горизонта
        double normalizedElev = (elevationData[i] - minElev) / elevRange;
        double y = vanishingPointY - (normalizedElev * 60);

        if (isFirstPoint) {
          terrainPath.moveTo(x, y);
          isFirstPoint = false;
        } else {
          terrainPath.lineTo(x, y);
        }
      }
    }

    // Замыкаем путь вниз до горизонта
    terrainPath.lineTo(size.width, vanishingPointY);
    terrainPath.lineTo(0, vanishingPointY);
    terrainPath.close();

    // Рисуем рельеф полупрозрачным зелёным (как дальние холмы)
    final terrainPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawPath(terrainPath, terrainPaint);

    // Рисуем линию профиля (контур)
    final profilePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(terrainPath, profilePaint);
  }

  void _drawRoad(
    Canvas canvas,
    Size size,
    double vanishingPointX,
    double vanishingPointY,
  ) {
    final roadPath = Path();
    final roadWidthBottom = size.width * 0.8;
    final roadWidthHorizon = 20.0;

    roadPath.moveTo(vanishingPointX - roadWidthHorizon, vanishingPointY);
    roadPath.lineTo(vanishingPointX - roadWidthBottom, size.height);
    roadPath.lineTo(vanishingPointX + roadWidthBottom, size.height);
    roadPath.lineTo(vanishingPointX + roadWidthHorizon, vanishingPointY);
    roadPath.close();

    final roadPaint = Paint()
      ..color = const Color(0xFF424242)
      ..style = PaintingStyle.fill;
    canvas.drawPath(roadPath, roadPaint);

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final animationOffset = (currentDistance * 50) % 100;

    for (double i = animationOffset; i < size.height; i += 100) {
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

    // БОЛЬШИЕ смещения для выраженного 3/4 ракурса
    final offsetX = 40.0; // Насколько вбок сдвигаем ближние элементы
    final offsetY = 15.0; // Насколько вниз сдвигаем ближние элементы

    // Тень (смещена вправо)
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + offsetX * 0.5, bottomY + 10),
        width: 80,
        height: 20,
      ),
      shadowPaint,
    );

    // Заднее колесо (наклоненный эллипс - виден правый бок)
    final wheelPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, bottomY),
        width: 50, // Широкое колесо (вид сбоку)
        height: 45,
      ),
      wheelPaint,
    );

    // Спицы (вращаются по эллипсу)
    final spokePaint = Paint()
      ..color = const Color(0xFF757575)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final wheelRotation = (currentDistance * 10) % (2 * math.pi);
    final wheelRadiusX = 25.0;
    final wheelRadiusY = 22.5;

    for (int i = 0; i < 4; i++) {
      final angle = wheelRotation + (i * math.pi / 2);
      final x1 = centerX + math.cos(angle) * wheelRadiusX;
      final y1 = bottomY + math.sin(angle) * wheelRadiusY;
      final x2 = centerX + math.cos(angle + math.pi) * wheelRadiusX;
      final y2 = bottomY + math.sin(angle + math.pi) * wheelRadiusY;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), spokePaint);
    }

    // ЛЕВАЯ НОГА (дальняя) - рисуем ПЕРВОЙ
    final legPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final crankCenterX = centerX + offsetX * 0.3;
    final crankCenterY = bottomY - 5;
    final crankRadiusX = 20.0;
    final crankRadiusY = 25.0;

    final leftHipX = centerX - 10;
    final leftHipY = bottomY - 30;

    final leftPedalX =
        crankCenterX + math.cos(pedalAngle + math.pi) * crankRadiusX;
    final leftPedalY =
        crankCenterY + math.sin(pedalAngle + math.pi) * crankRadiusY;

    // Левая нога
    double leftKneeX = (leftHipX + leftPedalX) / 2;
    double leftKneeY = (leftHipY + leftPedalY) / 2 + 5;
    canvas.drawLine(
        Offset(leftHipX, leftHipY), Offset(leftKneeX, leftKneeY), legPaint);
    canvas.drawLine(
        Offset(leftKneeX, leftKneeY), Offset(leftPedalX, leftPedalY), legPaint);

    // Левая педаль
    final pedalPaint = Paint()..color = const Color(0xFF757575);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(leftPedalX, leftPedalY),
        width: 14,
        height: 7,
      ),
      pedalPaint,
    );

    // Рама (параллелограмм - наклонена вправо)
    final bikePaint = Paint()
      ..color = const Color(0xFF00BCD4)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    // Левая стойка (дальняя)
    canvas.drawLine(
      Offset(centerX - 20, bottomY - 35),
      Offset(centerX - 25, bottomY + 5),
      bikePaint,
    );
    // Правая стойка (ближняя)
    canvas.drawLine(
      Offset(centerX + 20, bottomY - 30),
      Offset(centerX + 30, bottomY + 10),
      bikePaint,
    );
    // Верхняя перекладина
    canvas.drawLine(
      Offset(centerX - 20, bottomY - 35),
      Offset(centerX + 20, bottomY - 30),
      bikePaint,
    );

    // Тело (трапеция - виден правый бок)
    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final bodyPath = Path();
    bodyPath.moveTo(centerX - 25, bottomY - 85); // Левое плечо (дальнее)
    bodyPath.lineTo(centerX + 35, bottomY - 80); // Правое плечо (ближнее)
    bodyPath.lineTo(centerX + 45, bottomY - 25); // Правый бок (ближний)
    bodyPath.lineTo(centerX - 30, bottomY - 30); // Левый бок (дальний)
    bodyPath.close();
    canvas.drawPath(bodyPath, bodyPaint);

    // ПРАВАЯ НОГА (ближняя) - рисуем ПОВЕРХ тела
    final rightHipX = centerX + 25;
    final rightHipY = bottomY - 25;

    final rightPedalX = crankCenterX + math.cos(pedalAngle) * crankRadiusX;
    final rightPedalY = crankCenterY + math.sin(pedalAngle) * crankRadiusY;

    // Правая нога
    double rightKneeX = (rightHipX + rightPedalX) / 2;
    double rightKneeY = (rightHipY + rightPedalY) / 2 + 5;
    canvas.drawLine(
        Offset(rightHipX, rightHipY), Offset(rightKneeX, rightKneeY), legPaint);
    canvas.drawLine(Offset(rightKneeX, rightKneeY),
        Offset(rightPedalX, rightPedalY), legPaint);

    // Правая педаль
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(rightPedalX, rightPedalY),
        width: 14,
        height: 7,
      ),
      pedalPaint,
    );

    // Каретка
    final crankPaint = Paint()..color = const Color(0xFF424242);
    canvas.drawCircle(Offset(crankCenterX, crankCenterY), 10, crankPaint);

    // Голова (смещена вправо)
    final headPaint = Paint()..color = const Color(0xFFFFCC80);
    canvas.drawCircle(
      Offset(centerX + offsetX * 0.4, bottomY - 95),
      20,
      headPaint,
    );

    // Шлем (смещен вправо)
    final helmetPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX + offsetX * 0.4, bottomY - 100),
        width: 42,
        height: 28,
      ),
      math.pi,
      math.pi,
      true,
      helmetPaint,
    );

    // Руки (правая ближе, левая дальше)
    final armPaint = Paint()
      ..color = const Color(0xFFFFCC80)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    // Левая рука (дальняя)
    canvas.drawLine(
      Offset(centerX - 20, bottomY - 65),
      Offset(centerX - 30, bottomY - 50),
      armPaint,
    );
    // Правая рука (ближняя)
    canvas.drawLine(
      Offset(centerX + 30, bottomY - 63),
      Offset(centerX + 45, bottomY - 48),
      armPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
