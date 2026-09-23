import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'bluetooth_manager.dart';
import 'perspective_road.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BluetoothManager(),
      child: const VeloApp(),
    ),
  );
}

class VeloApp extends StatelessWidget {
  const VeloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velo Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isShowingConnectionScreen = false;
  bool isRiding = false;
  Timer? _rideTimer;
  Duration rideDuration = Duration.zero;
  Duration movingDuration = Duration.zero;
  double distance = 0.0;
  double pedalAngle = 0.0;
  DateTime? _lastUpdateTime;

  List<double> elevationProfile = [];
  double totalRouteDistance = 10000.0;

  @override
  Widget build(BuildContext context) {
    final btManager = context.watch<BluetoothManager>();

    return Scaffold(
      appBar: isRiding
          ? null
          : AppBar(
              title: Text(
                isShowingConnectionScreen
                    ? 'Подключение'
                    : (btManager.isConnected ? ' В ЗАЕЗДЕ' : 'Моя Тренировка'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: isShowingConnectionScreen
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          isShowingConnectionScreen = false;
                        });
                      },
                    )
                  : null,
              actions: [
                if (!isShowingConnectionScreen && !isRiding)
                  IconButton(
                    icon: Icon(
                      btManager.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_searching,
                      color: btManager.isConnected
                          ? Colors.greenAccent
                          : Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        isShowingConnectionScreen = true;
                      });
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),
      body: isRiding
          ? _buildRideScreen(btManager)
          : (isShowingConnectionScreen
                ? _buildConnectionUI(btManager)
                : _buildDashboardUI(btManager)),
    );
  }

  Widget _buildConnectionUI(BluetoothManager btManager) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Выберите устройство для подключения:',
            style: TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: btManager.isScanning ? null : btManager.startScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              btManager.isScanning ? 'ПОИСК...' : 'НАЧАТЬ ПОИСК УСТРОЙСТВ',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (btManager.isConnected) ...[
            Card(
              color: Colors.green.shade900.withOpacity(0.3),
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                ),
                title: Text(
                  btManager.connectedDevice?.platformName ?? 'Устройство',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Подключено и готово к работе',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: btManager.disconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'ОТКЛЮЧИТЬ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: btManager.foundDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
                            size: 48,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Устройства не найдены\nНажмите "Начать поиск"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: btManager.foundDevices.length,
                      itemBuilder: (context, index) {
                        var result = btManager.foundDevices[index];
                        return Card(
                          color: Colors.grey.shade800,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(
                              Icons.directions_bike,
                              color: Colors.blueAccent,
                            ),
                            title: Text(
                              result.device.platformName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              result.device.remoteId.str,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => btManager.connectToDevice(result),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDashboardUI(BluetoothManager btManager) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDataCard(
                'СКОРОСТЬ',
                btManager.speed.toStringAsFixed(1),
                'км/ч',
                Colors.blue,
              ),
              _buildDataCard(
                'МОЩНОСТЬ',
                btManager.power.toString(),
                'Вт',
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDataCard(
                'ПУЛЬС',
                btManager.heartRate.toString(),
                'уд/мин',
                Colors.red,
              ),
              _buildDataCard(
                'КАДЕНС',
                btManager.cadence.toString(),
                'об/мин',
                Colors.purple,
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: btManager.isConnected ? _startRide : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: btManager.isConnected
                  ? const Color(0xFF00E676)
                  : Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              btManager.isConnected
                  ? 'НАЧАТЬ ЗАЕЗД'
                  : 'СНАЧАЛА ПОДКЛЮЧИТЕ СТАНОК',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: btManager.isConnected
                    ? Colors.black
                    : Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildRideScreen(BluetoothManager btManager) {
    return Stack(
      children: [
        Column(
          children: [
            SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade800, width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCompactMetric(
                          btManager.speed.toStringAsFixed(1),
                          'км/ч',
                          Colors.blue,
                        ),
                        _buildCompactMetric(
                          btManager.power.toString(),
                          'Вт',
                          Colors.orange,
                        ),
                        _buildCompactMetric(
                          btManager.heartRate.toString(),
                          'уд/м',
                          Colors.red,
                        ),
                        _buildCompactMetric(
                          btManager.cadence.toString(),
                          'об/м',
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCompactMetric(
                          _formatDuration(rideDuration),
                          '',
                          Colors.white,
                        ),
                        _buildCompactMetric(
                          _formatDistance(distance),
                          '',
                          Colors.cyan,
                        ),
                        _buildCompactMetric(
                          _formatDuration(movingDuration),
                          '',
                          Colors.greenAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: PerspectiveRoadPainter(
                    elevationData: elevationProfile,
                    currentDistance: distance,
                    totalDistance: totalRouteDistance,
                    currentSpeed: btManager.speed,
                    cadence: btManager.cadence.toDouble(),
                    pedalAngle: pedalAngle,
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showStopRideDialog,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.logout, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _generateTestRoute() {
    elevationProfile.clear();
    int points = 1000;
    for (int i = 0; i < points; i++) {
      double progress = i / points;
      double elevation = 100.0;
      elevation += 50 * math.sin(progress * 3.14 * 2);
      elevation += 30 * math.sin(progress * 3.14 * 4 + 1);
      elevation += 10 * math.sin(progress * 3.14 * 8 + 2);
      elevationProfile.add(elevation);
    }
  }

  void _startRide() {
    _generateTestRoute();

    setState(() {
      isRiding = true;
      rideDuration = Duration.zero;
      movingDuration = Duration.zero;
      distance = 0.0;
      pedalAngle = 0.0;
      _lastUpdateTime = null;
    });
    print("🚴 Заезд начат!");

    _rideTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final now = DateTime.now();
      final deltaTime = _lastUpdateTime != null
          ? now.difference(_lastUpdateTime!).inMilliseconds / 1000.0
          : 0.016;
      _lastUpdateTime = now;

      final btManager = context.read<BluetoothManager>();

      setState(() {
        rideDuration += const Duration(milliseconds: 16);

        if (btManager.speed > 1.0) {
          movingDuration += const Duration(milliseconds: 16);
        }

        distance += (btManager.speed / 3.6) * deltaTime;
        pedalAngle += btManager.cadence * (2 * math.pi / 60) * deltaTime;
      });
    });
  }

  void _showStopRideDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'Закончить поездку?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Дистанция: ${_formatDistance(distance)}\nВремя: ${_formatDuration(rideDuration)}',
            style: const TextStyle(color: Colors.grey),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ОТМЕНА', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _stopRide();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'ЗАВЕРШИТЬ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _stopRide() {
    _rideTimer?.cancel();
    _rideTimer = null;

    setState(() {
      isRiding = false;
      distance = 0.0;
    });
    print("🏁 Заезд завершен!");
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} м';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} км';
    }
  }

  Widget _buildCompactMetric(String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value$unit',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDataCard(String title, String value, String unit, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
