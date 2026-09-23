import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothManager extends ChangeNotifier {
  // Состояние
  bool isScanning = false;
  bool isConnected = false;
  List<ScanResult> foundDevices = [];
  BluetoothDevice? connectedDevice;
  StreamSubscription<List<int>>? _dataSubscription;

  // Данные тренировки
  double speed = 0.0;
  int power = 0;
  int heartRate = 0;
  int cadence = 0;

  // Сканирование устройств
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
        withServices: [
          Guid("1826"), // Fitness Machine
          Guid("1818"), // Cycling Power
          Guid("180D"), // Heart Rate
        ],
      );

      FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          String deviceName = result.device.platformName;

          bool isFitnessDevice =
              deviceName.toLowerCase().contains('tacx') ||
              deviceName.toLowerCase().contains('wahoo') ||
              deviceName.toLowerCase().contains('elite') ||
              deviceName.toLowerCase().contains('garmin') ||
              deviceName.toLowerCase().contains('polar') ||
              deviceName.toLowerCase().contains('suunto') ||
              deviceName.toLowerCase().contains('magene') ||
              deviceName.toLowerCase().contains('kenshi');

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

  // Подключение к устройству
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

        // Подключение к велостанку (1826)
        if (uuid.contains("1826")) {
          print("🎯 Найден сервис станка (1826)");
          for (var char in service.characteristics) {
            if (char.uuid.toString().toUpperCase().contains("2AD2")) {
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
              break;
            }
          }
        }

        // Подключение к пульсометру (180D)
        if (uuid.contains("180D")) {
          print("🎯 Найден сервис пульсометра (180D)");
          for (var char in service.characteristics) {
            if (char.uuid.toString().toUpperCase().contains("2A37")) {
              print("🎯 Канал данных пульса (2A37)");
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                if (value.isNotEmpty) {
                  // Формат: флаги + значение пульса (1 или 2 байта)
                  int flags = value[0];
                  if (flags & 0x01 == 0) {
                    // 8-битное значение
                    heartRate = value[1];
                  } else {
                    // 16-битное значение
                    heartRate = value[1] | (value[2] << 8);
                  }
                  notifyListeners();
                }
              });
              break;
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

  // Отключение
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
    notifyListeners();
    print("🔌 Отключено");
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }
}
