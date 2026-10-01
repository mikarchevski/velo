import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';
import 'metric_cards.dart';

class DashboardView extends StatelessWidget {
  final BluetoothManager btManager;
  final bool isPhone;
  final VoidCallback onStartRide;
  final bool devMode;

  const DashboardView({
    super.key,
    required this.btManager,
    required this.isPhone,
    required this.onStartRide,
    required this.devMode,
  });

  @override
  Widget build(BuildContext context) {
    final bool canStart = btManager.isConnected || devMode;

    if (isPhone) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DataCard(
                          title: 'СКОРОСТЬ',
                          value: btManager.speed.toStringAsFixed(1),
                          unit: 'км/ч',
                          color: Colors.blue,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DataCard(
                          title: 'МОЩНОСТЬ',
                          value: btManager.power.toString(),
                          unit: 'Вт',
                          color: Colors.orange,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DataCard(
                          title: 'ПУЛЬС',
                          value: btManager.heartRate.toString(),
                          unit: 'уд/м',
                          color: Colors.red,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DataCard(
                          title: 'КАДЕНС',
                          value: btManager.cadence.toString(),
                          unit: 'об/м',
                          color: Colors.purple,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canStart ? onStartRide : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canStart ? const Color(0xFF00E676) : Colors.grey.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    btManager.isConnected
                        ? 'НАЧАТЬ ЗАЕЗД'
                        : (devMode ? 'НАЧАТЬ ЗАЕЗД (ДЕМО)' : 'ПОДКЛЮЧИТЕ СТАНОК'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: canStart ? Colors.black : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DataCard(
                  title: 'СКОРОСТЬ',
                  value: btManager.speed.toStringAsFixed(1),
                  unit: 'км/ч',
                  color: Colors.blue,
                ),
                DataCard(
                  title: 'МОЩНОСТЬ',
                  value: btManager.power.toString(),
                  unit: 'Вт',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DataCard(
                  title: 'ПУЛЬС',
                  value: btManager.heartRate.toString(),
                  unit: 'уд/мин',
                  color: Colors.red,
                ),
                DataCard(
                  title: 'КАДЕНС',
                  value: btManager.cadence.toString(),
                  unit: 'об/мин',
                  color: Colors.purple,
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: canStart ? onStartRide : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canStart ? const Color(0xFF00E676) : Colors.grey.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(
                  btManager.isConnected
                      ? 'НАЧАТЬ ЗАЕЗД'
                      : (devMode ? 'НАЧАТЬ ЗАЕЗД (ДЕМО)' : 'СНАЧАЛА ПОДКЛЮЧИТЕ СТАНОК'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: canStart ? Colors.black : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}