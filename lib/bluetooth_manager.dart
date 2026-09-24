import 'dart:async';
import 'dart:typed_data'; // Обязательно для ByteData

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothManager extends ChangeNotifier {
  bool isScanning = false;
  bool isConnected = false;
  List<ScanResult> foundDevices = [];
  BluetoothDevice? connectedDevice;
  StreamSubscription<List<int>>? _dataSubscription;

  // Характеристики управления
  BluetoothCharacteristic?
      _controlPointCharacteristic; // 2AD9 (ГЛАВНОЕ для управления)

  double speed = 0.0;
  int power = 0;
  int heartRate = 0;
  int cadence = 0;
  double gradient = 0.0;

  Future<void> startScan() async {
    isScanning = true;
    foundDevices.clear();
    notifyListeners();

    try {
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        print("❌ Bluetooth выключен!");
        isScanning = false;
        notifyListeners();
        return;
      }

      print("✅ Начинаем сканирование фитнес-устройств...");
      FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid("1826"), Guid("1818"), Guid("180D")],
      );

      FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          String deviceName = result.device.platformName;
          bool isFitnessDevice = deviceName.toLowerCase().contains('tacx') ||
              deviceName.toLowerCase().contains('wahoo') ||
              deviceName.toLowerCase().contains('elite') ||
              deviceName.toLowerCase().contains('garmin');

          if (deviceName.isNotEmpty &&
              !foundDevices.any((r) => r.device.platformName == deviceName) &&
              isFitnessDevice) {
            foundDevices.add(result);
            print("🎯 Найдено: $deviceName");
            notifyListeners();
          }
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      FlutterBluePlus.stopScan();
      isScanning = false;
      notifyListeners();
      print("⏹️ Сканирование завершено.");
    } catch (e) {
      print("⚠️ Ошибка сканирования: $e");
      isScanning = false;
      notifyListeners();
    }
  }

  // ПРАВИЛЬНЫЙ СПОСОБ: Отправка через Контрольную точку (2AD9)
  // ПРАВИЛЬНЫЙ СПОСОБ для симуляции рельефа: Indoor Bike Simulation (Opcode 0x12)
  // ПРАВИЛЬНЫЙ СПОСОБ для симуляции рельефа: Indoor Bike Simulation (Opcode 0x12)
  Future<void> setSimulationParameters(double gradientPercent) async {
    if (_controlPointCharacteristic == null || !isConnected) {
      print("❌ Control Point не найден или станок не подключен");
      return;
    }

    try {
      // 1. Request Control
      final requestControl = Uint8List.fromList([
        0x00,
      ]);

      await _controlPointCharacteristic!.write(
        requestControl,
        withoutResponse: false,
      );

      print("📤 REQUEST_CONTROL: 00");

      await Future.delayed(const Duration(milliseconds: 100));

      // 2. Set Indoor Bike Simulation Parameters
      final safeGradient = gradientPercent.clamp(-20.0, 20.0);

      final data = ByteData(7);

      // Opcode
      data.setUint8(0, 0x11);

      // Wind Speed: 0 m/s
      data.setInt16(1, 0, Endian.little);

      // Grade: percentage * 100
      data.setInt16(
        3,
        (safeGradient * 100).round(),
        Endian.little,
      );

      // Crr = 0.005
      // resolution 0.0001
      // 0.005 / 0.0001 = 50
      data.setUint8(5, 50);

      // Cw = 0.51 kg/m
      // resolution 0.01
      // 0.51 / 0.01 = 51
      data.setUint8(6, 51);

      final bytes = data.buffer.asUint8List();

      print(
        "📤 SIMULATION: "
        "${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}",
      );

      await _controlPointCharacteristic!.write(
        bytes,
        withoutResponse: false,
      );

      print(
        "🏔️ Градиент ${safeGradient.toStringAsFixed(2)}% отправлен",
      );
    } catch (e) {
      print("❌ ОШИБКА отправки симуляции: $e");
    }
  }

  void updateGradient(List<double> elevationData, double currentDistance,
      double totalDistance) {
    if (elevationData.isEmpty || totalDistance == 0) {
      if (gradient != 0.0) {
        gradient = 0.0;
        notifyListeners();
      }
      return;
    }

    int currentIndex =
        ((currentDistance / totalDistance) * elevationData.length).floor();
    int aheadIndex =
        currentIndex + 5; // Смотрим на 5 точек вперед для сглаживания

    if (currentIndex < 0 || currentIndex >= elevationData.length) return;
    if (aheadIndex >= elevationData.length)
      aheadIndex = elevationData.length - 1;

    double elevDiff = elevationData[aheadIndex] - elevationData[currentIndex];
    double distanceDiff =
        (aheadIndex - currentIndex) / elevationData.length * totalDistance;

    if (distanceDiff > 0) {
      double newGradient = (elevDiff / distanceDiff) * 100;
      newGradient = newGradient.clamp(-25.0, 25.0);

      if ((newGradient - gradient).abs() > 0.1) {
        gradient = newGradient;
        notifyListeners();
      }
    }
  }

  Future<void> connectToDevice(ScanResult result) async {
    FlutterBluePlus.stopScan();
    isScanning = false;
    notifyListeners();
    print("🔌 Подключение к ${result.device.platformName}...");

    try {
      await result.device.connect();
      isConnected = true;
      connectedDevice = result.device;
      notifyListeners();
      print("✅ Подключено!");

      List<BluetoothService> services = await result.device.discoverServices();

      for (var service in services) {
        String uuid = service.uuid.toString().toUpperCase();

        if (uuid.contains("1826")) {
          // Fitness Machine Service
          print("🎯 Найден сервис станка (1826)");
          for (var char in service.characteristics) {
            String charUuid = char.uuid.toString().toUpperCase();

            if (charUuid.contains("2AD2")) {
              // Indoor Bike Data
              print("🎯 Канал данных станка (2AD2)");
              await char.setNotifyValue(true);
              _dataSubscription = char.onValueReceived.listen((value) {
                if (value.length >= 8) {
                  int speedRaw = value[2] | (value[3] << 8);
                  int cadenceRaw = value[4] | (value[5] << 8);
                  int powerRaw = value[6] | (value[7] << 8);
                  if (powerRaw > 32767) powerRaw -= 65536;

                  speed = speedRaw * 0.01;
                  cadence = (cadenceRaw * 0.5).toInt();
                  power = powerRaw;
                  notifyListeners();
                }
              });
            }

            // КРИТИЧЕСКИ ВАЖНО: Ищем Контрольную точку
            if (charUuid.contains("2AD9")) {
              print("🎯 НАЙДЕНА Контрольная точка управления (2AD9)!");
              _controlPointCharacteristic = char;
            }
          }
        }

        if (uuid.contains("180D")) {
          // Heart Rate
          for (var char in service.characteristics) {
            if (char.uuid.toString().toUpperCase().contains("2A37")) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                if (value.isNotEmpty) {
                  int flags = value[0];
                  heartRate = (flags & 0x01 == 0)
                      ? value[1]
                      : (value[1] | (value[2] << 8));
                  notifyListeners();
                }
              });
            }
          }
        }
      }
      print("✅ Подписка на данные активна. КРУТИТЕ ПЕДАЛИ!");
    } catch (e) {
      print("❌ Ошибка подключения: $e");
      isConnected = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_dataSubscription != null) {
      await _dataSubscription!.cancel();
      _dataSubscription = null;
    }
    await connectedDevice?.disconnect();
    isConnected = false;
    connectedDevice = null;
    speed = 0.0;
    power = 0;
    heartRate = 0;
    cadence = 0;
    gradient = 0.0;
    notifyListeners();
    print("🔌 Отключено");
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }
}
