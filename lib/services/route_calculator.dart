// lib/services/route_calculator.dart
import 'dart:math';

class RouteState {
  final double currentDistance;
  final double currentElevation;
  final double gradient; // Сглаженный, готовый для UI и BLE

  RouteState({
    required this.currentDistance,
    required this.currentElevation,
    required this.gradient,
  });
}

class ElevationCalculator {
  final List<double> elevationData;
  final double totalDistance;

  final double lookAheadDistance = 20.0; // Смотрим на 20м вперед
  final double smoothingFactor = 0.3; // Сглаживание (0.0 - 1.0)

  double _previousGradient = 0.0;

  ElevationCalculator({
    required this.elevationData,
    required this.totalDistance,
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

  RouteState update(double currentDistance) {
    final currentElev = _getElevationAt(currentDistance);
    final futureElev = _getElevationAt(currentDistance + lookAheadDistance);

    double rawGradient = ((futureElev - currentElev) / lookAheadDistance) * 100;

    // Экспоненциальное сглаживание
    _previousGradient = (rawGradient * smoothingFactor) +
        (_previousGradient * (1 - smoothingFactor));

    final smoothGradient = _previousGradient.clamp(-20.0, 20.0);

    return RouteState(
      currentDistance: currentDistance,
      currentElevation: currentElev,
      gradient: smoothGradient,
    );
  }
}
