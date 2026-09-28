import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final serviceUuid = Guid("69b61d63-0927-4bea-92c7-28a0020a844a");
final textCharacteristicUuid = Guid("9631882c-b69b-4677-9735-da022e2eb58f");
final pictureStartCharacterisitcUuid = Guid("ec33a9d4-722e-4385-9e71-9ce7acfa82e8");
final pictureCharacteristicUuid = Guid("b31c1597-6e57-4871-97f1-39f3ffdeb73a");


class BLEConnection {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? textCharacteristic;
  BluetoothCharacteristic? pictureStartCharacteristic;
  BluetoothCharacteristic? pictureCharacteristic;

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _monitorTimer;
  bool isConnected = false;

  Future<void> init() async {
    _scan();
  }

  Future<void> monitorConnection() async {
    if (connectedDevice == null) return;

    _connectionSubscription = connectedDevice!.connectionState.listen((state) {
      isConnected = state == BluetoothConnectionState.connected;

      if (!isConnected) {
        _handleDisconnect();
      }
    });

    _monitorTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _healthCheck(),
    );
  }


  Future<void> _scan() async {
    late final subscription;

    subscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        for (final result in results) {
          if (result.device.platformName == "Overall-LCD") {
            await FlutterBluePlus.stopScan();
            await subscription.cancel();
            await _connect(result.device);
            return;
          }
        }
      },
      onError: (error) {
        debugPrint('Scan Error: $error');
      },
    );

    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint("Scan konnte nicht gestartet werden: $e");
      await subscription.cancel();
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await device.connect(license: License.nonprofit);
      connectedDevice = device;
      await _discoverServices(device);
    } catch (e) {
      debugPrint("Verbindung fehlgeschlagen: $e");
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == serviceUuid) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == textCharacteristicUuid) {
            textCharacteristic = characteristic;
          }
          if (characteristic.uuid == pictureCharacteristicUuid) {
            pictureCharacteristic = characteristic;
          }
          if (characteristic.uuid == pictureStartCharacterisitcUuid) {
            pictureStartCharacteristic = characteristic;
          }
        }
      }
    }
  }

  Future<void> _healthCheck() async {
    if (connectedDevice == null) return;

    final state = await connectedDevice!.connectionState.first;

    if (state != BluetoothConnectionState.connected) {
      isConnected = false;
      await _handleDisconnect();
    }
  }

  Future<void> _handleDisconnect() async {
    _scan();
    print('BLE Verbindung verloren');
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _monitorTimer?.cancel();
  }

  Future<void> sendText(String jsonTextData) async {
    if (textCharacteristic == null) {
      debugPrint("Keine Text-Characteristic verbunden!");
      return;
    }

    final data = utf8.encode(jsonTextData);
    await textCharacteristic!.write(data);

    debugPrint("Gesendet: $jsonTextData");
  }

  Future<void> sendPicture(List<int> picture) async {
    if (connectedDevice == null) {
      debugPrint("Kein verbundenes Geraet verfuegbar!");
      return;
    }
    if (pictureStartCharacteristic == null) {
      debugPrint("Keine Picture-Characteristic verbunden!");
      return;
    }
    if (pictureCharacteristic == null) {
      debugPrint("Keine Picture-Characteristic verbunden!");
      return;
    }

    await connectedDevice!.requestMtu(515);
    final maxPayload = connectedDevice!.mtuNow - 3;
    debugPrint('MTU: ${maxPayload}');

    final bytes = Uint8List(picture.length * 2);
    final data = ByteData.sublistView(bytes);

    for (int i = 0; i < picture.length; i++) {
      data.setUint16(i * 2, picture[i], Endian.little);
    }

    await pictureStartCharacteristic!.write(utf8.encode(jsonEncode({"start":true})));

    for (int i = 0; i<bytes.length; i+=maxPayload) {
      //await Future.delayed(const Duration(milliseconds: 5));
      final end = (i + maxPayload < bytes.length)
        ? i + maxPayload
        : bytes.length;

      final chunk = bytes.sublist(i, end);
      await pictureCharacteristic!.write(
        chunk,
        withoutResponse: true,
      );
    }
  }
}