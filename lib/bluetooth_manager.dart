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
      return;
    }

    try {
      // ШАГ 1: Всегда запрашиваем контроль перед отправкой команд (Opcode 0x00)
      ByteData requestControl = ByteData(1);
      requestControl.setUint8(0, 0x00);
      await _controlPointCharacteristic!.write(
        requestControl.buffer.asUint8List(),
        withoutResponse: false,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // ШАГ 2: Отправляем параметры симуляции (Opcode 0x12)
      ByteData data = ByteData(9);
      data.setUint8(0, 0x12); // Opcode: Set Indoor Bike Simulation Parameters

      // Байты 1-2: Скорость ветра (м/с) * 1000. Пока 0.
      data.setInt16(1, 0, Endian.little);

      // Байты 3-4: Уклон (%) * 100
      double safeGradient = gradientPercent.clamp(-20.0, 20.0);
      data.setInt16(3, (safeGradient * 100).round(), Endian.little);

      // Байты 5-6: Crr (Коэффициент сопротивления качению) * 10000
      data.setUint16(5, 50, Endian.little); // 0.005

      // Байты 7-8: Коэффициент сопротивления ветру * 1000
      data.setUint16(7, 510, Endian.little); // 0.51

      await _controlPointCharacteristic!.write(
        data.buffer.asUint8List(),
        withoutResponse: false,
      );

      print(
          "🏔️ СИМУЛЯЦИЯ: Уклон ${safeGradient.toStringAsFixed(1)}% отправлен на станок");
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
