import 'package:flutter/material.dart';
import '../bluetooth_manager.dart';

class ConnectionView extends StatelessWidget {
  final BluetoothManager btManager;
  final VoidCallback onBack;

  const ConnectionView({super.key, required this.btManager, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Выберите устройство для подключения:', style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: btManager.isScanning ? null : btManager.startScan,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: Text(btManager.isScanning ? 'ПОИСК...' : 'НАЧАТЬ ПОИСК УСТРОЙСТВ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          if (btManager.isConnected) ...[
            Card(
              color: Colors.green.shade900.withOpacity(0.3),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
                title: Text(btManager.connectedDevice?.platformName ?? 'Устройство', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Подключено и готово к работе', style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: btManager.disconnect,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('ОТКЛЮЧИТЬ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ] else ...[
            Expanded(
              child: btManager.foundDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey.shade700),
                          const SizedBox(height: 10),
                          Text('Устройства не найдены\nНажмите "Начать поиск"', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600))
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
                            leading: const Icon(Icons.directions_bike, color: Colors.blueAccent),
                            title: Text(result.device.platformName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(result.device.remoteId.str, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
}