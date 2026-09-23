import 'package:flutter/material.dart';

import 'dart:ui' as ui;

// Класс для отрисовки 2D-трассы
class ElevationRoadPainter extends CustomPainter {
  final List<double> elevationData;
  final double currentDistance;
  final double totalDistance;
  final double currentSpeed;

  ElevationRoadPainter({
    required this.elevationData,
    required this.currentDistance,
    required this.totalDistance,
    required this.currentSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elevationData.isEmpty) return;

    // Определяем диапазон высот для масштабирования
    double minElev = elevationData.reduce((a, b) => a < b ? a : b);
    double maxElev = elevationData.reduce((a, b) => a > b ? a : b);
    double elevRange = maxElev - minElev;
    if (elevRange == 0) elevRange = 1;

    // Рисуем фон (небо)
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [
        const Color(0xFF1A237E), // Темно-синий
        const Color(0xFF3949AB), // Светлее
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Рисуем землю/дорогу
    final roadPaint = Paint()
      ..color =
          const Color(0xFF2E7D32) // Зеленый цвет травы
      ..style = PaintingStyle.fill;

    final path = Path();
    bool isFirstPoint = true;

    // Показываем участок трассы вокруг текущей позиции
    double viewRange = 500.0; // Показываем 500м вперед и назад
    double screenStartDistance = currentDistance - viewRange;
    double screenEndDistance = currentDistance + viewRange * 2;

    for (int i = 0; i < elevationData.length; i++) {
      double pointDistance = (i / elevationData.length) * totalDistance;

      if (pointDistance >= screenStartDistance &&
          pointDistance <= screenEndDistance) {
        double x =
            ((pointDistance - screenStartDistance) /
                (screenEndDistance - screenStartDistance)) *
            size.width;
        double y =
            size.height -
            ((elevationData[i] - minElev) / elevRange) * (size.height * 0.5) -
            50;

        if (isFirstPoint) {
          path.moveTo(x, y);
          isFirstPoint = false;
        } else {
          path.lineTo(x, y);
        }
      }
    }

    // Замыкаем путь вниз, чтобы залить землю
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, roadPaint);

    // Рисуем линию дороги (асфальт)
    final roadLinePaint = Paint()
      ..color =
          const Color(0xFF424242) // Серый асфальт
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, roadLinePaint);

    // Рисуем аватар (велосипедист)
    double avatarX = size.width * 0.3; // Аватар на 30% экрана слева

    // Находим высоту в текущей точке
    int currentIndex =
        ((currentDistance / totalDistance) * elevationData.length)
            .floor()
            .clamp(0, elevationData.length - 1);
    double currentElev = elevationData[currentIndex];
    double avatarY =
        size.height -
        ((currentElev - minElev) / elevRange) * (size.height * 0.5) -
        50;

    // Рисуем кружок-аватар
    final avatarPaint = Paint()..color = const Color(0xFFFFEB3B); // Желтый
    canvas.drawCircle(Offset(avatarX, avatarY), 15, avatarPaint);

    // Обводка аватара
    final avatarBorderPaint = Paint()
      ..color = const Color(0xFFFF6F00)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(avatarX, avatarY), 15, avatarBorderPaint);

    // Эффект свечения при высокой скорости
    if (currentSpeed > 25) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.3)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
      canvas.drawCircle(Offset(avatarX, avatarY), 25, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Перерисовывать при каждом изменении
  }
}
