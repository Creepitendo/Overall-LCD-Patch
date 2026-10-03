import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:lcd_application/ble_communication.dart';
import 'package:lcd_application/rest_communication.dart';
import 'package:lcd_application/config.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LcdBackgroundTask());
}

class BackgroundCommands {
  static const String sendText = 'sendText';
  static const String sendPicture = 'sendPicture';

  static const String setServerMode = 'setServerMode';
  static const String initBLE = 'initBLE';
  static const String stop = 'stop';
}

class LcdBackgroundTask extends TaskHandler {
  BLEConnection? ble;
  RESTService? rest;

  bool useServer = false;
  bool _polling = false;

  bool _lastBleStatus = false;


  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    rest = RESTService(requestServerURL);
    ble = BLEConnection();

    ble!.isConnected.addListener(_onBleStatusChanged);

    FlutterForegroundTask.sendDataToMain({
      'type': 'backgroundReady',
    });
  }

  void _onBleStatusChanged() {
    final connected = ble?.isConnected.value ?? false;

    if (connected == _lastBleStatus) {
      return;
    }
    _lastBleStatus = connected;
    FlutterForegroundTask.sendDataToMain({
      'type': 'bleStatus',
      'connected': connected,
    });
  }

  Future<void> _pollServer() async {
    if (_polling) {
      return;
    }

    _polling = true;

    if (ble == null || !ble!.isConnected.value) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'error',
        'message': 'BLE not connected',
      });
      _polling = false;
      return;
    }
    if (!useServer) {
      _polling = false;
      return;
    }

    try {
      final data = await rest!.getLCDRequest();

      if (data['dataPresent'] != true) {
        return;
      }

      if (data["dataPresent"]) {
        if (data["type"] == "text") {
          ble!.sendText(jsonEncode(data["data"]));
        }
        else if (data["type"] == "picture") {
          ble!.sendPicture(List<int>.from(data["data"]["picture"]));
        }
        else {
          throw Exception(
            "Request-Server Datatype not valid: ${data["type"]}",
          );
        }
      }

      FlutterForegroundTask.sendDataToMain({
        'type': 'requestSent',
        'queueCount': data['queueCount'],
      });

    } 
    catch (e, stackTrace) {
      print('Background REST/BLE Error: $e');
      print(stackTrace);

      FlutterForegroundTask.sendDataToMain({
        'type': 'error',
        'message': e.toString(),
      });
    } 
    finally {
      _polling = false;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _pollServer();
  }

  @override
  void onReceiveData(Object data) async {
    if (data is! Map) {
      return;
    }

    final command = data['command'];

    switch (command) {

      case BackgroundCommands.sendText:
        await _handleSendText(data);
        break;

      case BackgroundCommands.sendPicture:
        await _handleSendPicture(data);
        break;

      case BackgroundCommands.setServerMode:
        useServer = data['value'];
        break;

      case BackgroundCommands.initBLE:
        if (!ble!.isConnected.value) {
          await ble!.init();
        }
        break;

      case BackgroundCommands.stop:
        await _stop();
        break;
    }
  }

  Future<void> _handleSendText(Map data) async {
    final textData = data['data'];

    if (textData is! String) {
      return;
    }

    try {
      if (!useServer && ble != null && ble!.isConnected.value) {
        await ble!.sendText(textData);
      }
      else {
        final answer = await rest!.uploadText(jsonEncodedTextData: textData);

        FlutterForegroundTask.sendDataToMain({
          'type': 'uploadResponse',
          'queueCount': answer['queueCount'],
        });
      }
    }

    catch (e) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'error',
        'message': e.toString(),
      });
    }
  }


  Future<void> _handleSendPicture(Map data) async {
    final picture = data['data'];

    if (picture is! List) {
      return;
    }

    try {
      final image = List<int>.from(picture);

      if (!useServer && ble != null && ble!.isConnected.value) {
        await ble!.sendPicture(image);
      }
      else {
        final answer = await rest!.uploadPicture(
          picture: image,
        );

        FlutterForegroundTask.sendDataToMain({
          'type': 'uploadResponse',
          'queueCount': answer['queueCount'],
        });
      }
    }

    catch (e) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'error',
        'message': e.toString(),
      });
    }
  }

  Future<void> _stop() async {
    ble?.dispose();
    ble = null;
    rest = null;
    await FlutterForegroundTask.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    ble?.isConnected.removeListener(_onBleStatusChanged);
    ble?.dispose();

    ble = null;
    rest = null;
  }

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationDismissed() {}
}