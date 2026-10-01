import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'bluetooth_manager.dart';
import 'widgets/gpx_loader.dart';
import 'services/route_calculator.dart';
import 'widgets/connection_view.dart';
import 'widgets/dashboard_view.dart';
import 'widgets/active_ride_view.dart';


const bool DEV_MODE = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BluetoothManager())],
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

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  bool isShowingConnectionScreen = false;
  bool isRiding = false;
  Timer? _rideTimer;
  RouteData? _currentRoute;

  Duration rideDuration = Duration.zero;
  Duration movingDuration = Duration.zero;
  double distance = 0.0;
  double pedalAngle = 0.0;
  DateTime? _lastUpdateTime;

  ElevationCalculator? _elevationCalculator;
  RouteState? _currentRouteState;

  double _currentSpeedKmh = 0.0;
  late final Ticker _roadTicker;
  final ValueNotifier<double> _roadPhaseNotifier = ValueNotifier(0.0);
  double _lastTickTime = 0.0;
  DateTime _lastSimulationUpdate = DateTime.now();

  List<double> elevationProfile = [];
  double totalRouteDistance = 10000.0;
  double _cyclistBounce = 0.0;

  bool _isSimulating = false;
  double _mockSpeed = 0.0;
  int _mockCadence = 0;
  int _mockPower = 150;
  int _mockHeartRate = 130;

  void _toggleSimulation() {
    setState(() {
      _isSimulating = !_isSimulating;
      if (_isSimulating) {
        _mockSpeed = 25.0;
        _mockCadence = 90;
      } else {
        _mockSpeed = 0.0;
        _mockCadence = 0;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _roadTicker = createTicker((elapsed) {
      if (!isRiding) return;
      final double now = elapsed.inMicroseconds / 1000000.0;
      final double deltaTime = _lastTickTime > 0 ? now - _lastTickTime : 0.016;
      _lastTickTime = now;

      if (_currentSpeedKmh > 0.5) {
        final double speedFactor = (_currentSpeedKmh / 30.0);
        double newPhase = _roadPhaseNotifier.value + speedFactor * deltaTime * 1.5;
        _roadPhaseNotifier.value = newPhase % 1.0;
        _cyclistBounce = -math.sin(pedalAngle) * 2.0;
      } else {
        _cyclistBounce = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _roadTicker.dispose();
    _roadPhaseNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btManager = context.watch<BluetoothManager>();
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;

    return Scaffold(
      appBar: isRiding
          ? null
          : AppBar(
              title: Text(isShowingConnectionScreen ? 'Подключение' : (btManager.isConnected ? 'В ЗАЕЗДЕ' : 'Моя Тренировка'), style: const TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: isShowingConnectionScreen
                  ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => isShowingConnectionScreen = false))
                  : null,
              actions: [
                if (!isShowingConnectionScreen && !isRiding)
                  IconButton(
                    icon: Icon(btManager.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching, color: btManager.isConnected ? Colors.greenAccent : Colors.white, size: 28),
                    onPressed: () => setState(() => isShowingConnectionScreen = true),
                  ),
                const SizedBox(width: 8),
              ],
            ),
      body: isRiding
          ? _buildActiveRideView(btManager, isPhone)
          : (isShowingConnectionScreen
              ? ConnectionView(btManager: btManager, onBack: () => setState(() => isShowingConnectionScreen = false))
              : DashboardView(btManager: btManager, isPhone: isPhone, onStartRide: _startRide, devMode: DEV_MODE)),
    );
  }

  Widget _buildActiveRideView(BluetoothManager btManager, bool isPhone) {
    final currentGrad = _currentRouteState?.gradient ?? 0.0;
    final displaySpeed = (DEV_MODE && !btManager.isConnected) ? _mockSpeed : btManager.speed;
    final displayCadence = (DEV_MODE && !btManager.isConnected) ? _mockCadence : btManager.cadence;
    final displayPower = (DEV_MODE && !btManager.isConnected) ? _mockPower : btManager.power;
    final displayHeartRate = (DEV_MODE && !btManager.isConnected) ? _mockHeartRate : btManager.heartRate;

    return ActiveRideView(
      btManager: btManager,
      isPhone: isPhone,
      distance: distance,
      rideDuration: rideDuration,
      movingDuration: movingDuration,
      currentGrad: currentGrad,
      displaySpeed: displaySpeed,
      displayCadence: displayCadence,
      displayPower: displayPower,
      displayHeartRate: displayHeartRate,
      roadPhaseNotifier: _roadPhaseNotifier,
      pedalAngle: pedalAngle,
      cyclistBounce: _cyclistBounce,
      elevationProfile: elevationProfile,
      totalRouteDistance: totalRouteDistance,
      curveData: _currentRoute?.curves ?? [],
      isSimulating: _isSimulating,
      onStopRide: _showStopRideDialog,
      onToggleSimulation: _toggleSimulation,
    );
  }

  Future<void> _loadRoute() async {
    final route = await GpxLoader.fromAsset('assets/tracks/test_climb.gpx');
    _currentRoute = route;
    if (route.isEmpty) {
      print("⚠️ Не удалось загрузить маршрут, используем фоллбэк");
      _generateFallbackRoute();
      return;
    }
    setState(() {
      _currentRoute = route; 
      elevationProfile = route.elevations;
      totalRouteDistance = route.totalDistance;
      _elevationCalculator = ElevationCalculator(elevationData: elevationProfile, totalDistance: totalRouteDistance);
      _currentRouteState = _elevationCalculator!.update(0.0);
    });
    print("✅ Загружен маршрут: ${route.name}");
  }

  void _generateFallbackRoute() {
    elevationProfile.clear();
    for (int i = 0; i < 1000; i++) {
      double progress = i / 1000.0;
      elevationProfile.add(100.0 + 50 * math.sin(progress * 3.14 * 2) + 30 * math.sin(progress * 3.14 * 4 + 1));
    }
    totalRouteDistance = 10000.0;
  }

  Future<void> _startRide() async {
    await _loadRoute();
    setState(() {
      isRiding = true;
      rideDuration = Duration.zero;
      movingDuration = Duration.zero;
      distance = 0.0;
      pedalAngle = 0.0;
      _lastUpdateTime = null;
      _lastSimulationUpdate = DateTime.now();
      _currentSpeedKmh = 0.0;
    });

    _rideTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final now = DateTime.now();
      final deltaTime = _lastUpdateTime != null ? now.difference(_lastUpdateTime!).inMilliseconds / 1000.0 : 0.1;
      _lastUpdateTime = now;

      final btManager = context.read<BluetoothManager>();
      final currentSpeed = (DEV_MODE && !btManager.isConnected) ? _mockSpeed : btManager.speed;
      final currentCadence = (DEV_MODE && !btManager.isConnected) ? _mockCadence : btManager.cadence;

      setState(() {
        rideDuration += const Duration(milliseconds: 100);
        if (currentSpeed > 1.0) movingDuration += const Duration(milliseconds: 100);
        distance += (currentSpeed / 3.6) * deltaTime;
        pedalAngle += currentCadence * (2 * math.pi / 60) * deltaTime;
        _currentSpeedKmh = currentSpeed;
      });

      if (_elevationCalculator != null) {
        _currentRouteState = _elevationCalculator!.update(distance);
        if (now.difference(_lastSimulationUpdate).inMilliseconds > 500) {
          _lastSimulationUpdate = now;
          if (btManager.isConnected) btManager.setSimulationParameters(_currentRouteState!.gradient);
        }
      }
    });

    _lastTickTime = 0.0;
    _roadPhaseNotifier.value = 0.0;
    _roadTicker.start();
  }

  void _showStopRideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Закончить поездку?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Дистанция: ${_formatDistance(distance)}\nВремя: ${_formatDuration(rideDuration)}', style: const TextStyle(color: Colors.grey)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ОТМЕНА', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { Navigator.of(context).pop(); _stopRide(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('ЗАВЕРШИТЬ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _stopRide() {
    _rideTimer?.cancel();
    _roadTicker.stop();
    setState(() {
      isRiding = false;
      distance = 0.0;
      _currentSpeedKmh = 0.0;
    });
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