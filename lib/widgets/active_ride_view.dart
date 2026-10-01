import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../bluetooth_manager.dart';
import '../perspective_road.dart';
import '../cyclist_legs_painter.dart';
import 'metric_cards.dart'; // 🚀 ИСПРАВЛЕНО: убран лишний префикс 'widgets/'

class ActiveRideView extends StatelessWidget {
  final BluetoothManager btManager;
  final bool isPhone;
  final double distance;
  final Duration rideDuration;
  final Duration movingDuration;
  final double currentGrad;
  final double displaySpeed;
  final int displayCadence;
  final int displayPower;
  final int displayHeartRate;
  final ValueNotifier<double> roadPhaseNotifier;
  final double pedalAngle;
  final double cyclistBounce;
  final List<double> elevationProfile;
  final double totalRouteDistance;
  final List<double> curveData;
  final bool isSimulating;
  final VoidCallback onStopRide;
  final VoidCallback onToggleSimulation;

  const ActiveRideView({
    super.key,
    required this.btManager,
    required this.isPhone,
    required this.distance,
    required this.rideDuration,
    required this.movingDuration,
    required this.currentGrad,
    required this.displaySpeed,
    required this.displayCadence,
    required this.displayPower,
    required this.displayHeartRate,
    required this.roadPhaseNotifier,
    required this.pedalAngle,
    required this.cyclistBounce,
    required this.elevationProfile,
    required this.totalRouteDistance,
    required this.curveData,
    required this.isSimulating,
    required this.onStopRide,
    required this.onToggleSimulation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: roadPhaseNotifier,
          builder: (context, phase, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: PerspectiveRoadPainter(
                elevationData: elevationProfile,
                currentDistance: distance,
                totalDistance: totalRouteDistance,
                currentGradient: currentGrad,
                currentSpeed: displaySpeed,
                cadence: displayCadence.toDouble(),
                roadAnimationPhase: phase,
                curveData: curveData,
              ),
            );
          },
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: isPhone ? 8 : 16, vertical: isPhone ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withOpacity(0.95),
                border: Border(bottom: BorderSide(color: Colors.grey.shade700, width: 1)),
              ),
              child: isPhone
                  ? Row(
                      children: [
                        CompactMetric(value: displaySpeed.toStringAsFixed(1), unit: 'км/ч', color: Colors.blue, valueSize: 22),
                        CompactMetric(value: displayPower.toString(), unit: 'Вт', color: Colors.orange, valueSize: 22),
                        CompactMetric(value: displayHeartRate.toString(), unit: 'уд/мин', color: Colors.red, valueSize: 22),
                        CompactMetric(value: displayCadence.toString(), unit: 'об/мин', color: Colors.purple, valueSize: 22),
                        CompactMetric(
                          value: (currentGrad >= 0 ? '+' : '') + currentGrad.toStringAsFixed(1) + '%',
                          unit: currentGrad > 2 ? 'подъем' : (currentGrad < -2 ? 'спуск' : 'ровно'),
                          color: currentGrad > 5 ? Colors.red : (currentGrad < -5 ? Colors.blue : Colors.orange),
                          valueSize: 22,
                        ),
                        CompactMetric(value: _formatDuration(rideDuration), unit: 'время', color: Colors.white, valueSize: 19),
                        CompactMetric(value: _formatDistance(distance), unit: 'дистанция', color: Colors.cyan, valueSize: 19),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            CompactMetric(value: displaySpeed.toStringAsFixed(1), unit: 'км/ч', color: Colors.blue),
                            CompactMetric(value: displayPower.toString(), unit: 'Вт', color: Colors.orange),
                            CompactMetric(value: displayHeartRate.toString(), unit: 'уд/м', color: Colors.red),
                            CompactMetric(value: displayCadence.toString(), unit: 'об/м', color: Colors.purple),
                            CompactMetric(
                              value: (currentGrad >= 0 ? '+' : '') + currentGrad.toStringAsFixed(1) + '%',
                              unit: currentGrad > 2 ? 'подъем' : (currentGrad < -2 ? 'спуск' : 'ровно'),
                              color: currentGrad > 5 ? Colors.red : (currentGrad < -5 ? Colors.blue : Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CompactMetric(value: _formatDuration(rideDuration), unit: 'время', color: Colors.white),
                            CompactMetric(value: _formatDistance(distance), unit: 'дистанция', color: Colors.cyan),
                            CompactMetric(value: _formatDuration(movingDuration), unit: 'движение', color: Colors.greenAccent),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 25,
          child: Center(
            child: Transform.translate(
              offset: Offset(0, cyclistBounce),
              child: SizedBox(
                width: 140, height: 168,
                child: Stack(
                  children: [
                    Positioned.fill(child: SvgPicture.asset('assets/images/cyclist.svg', fit: BoxFit.fill)),
                    Positioned.fill(child: CustomPaint(painter: CyclistLegsPainter(pedalAngle: pedalAngle))),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: isPhone ? 16 : 16, bottom: isPhone ? 16 : 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onStopRide,
              borderRadius: BorderRadius.circular(32),
              child: Container(
                width: isPhone ? 64 : 56, height: isPhone ? 64 : 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(Icons.stop_rounded, color: Colors.white, size: isPhone ? 32 : 28),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16, bottom: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleSimulation,
              borderRadius: BorderRadius.circular(32),
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: isSimulating ? Colors.greenAccent : Colors.grey.shade800,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(isSimulating ? Icons.pause : Icons.play_arrow, color: isSimulating ? Colors.black : Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String m = twoDigits(duration.inMinutes.remainder(60));
    String s = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? "${twoDigits(duration.inHours)}:$m:$s" : "$m:$s";
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} м';
    return '${(meters / 1000).toStringAsFixed(2)} км';
  }
}