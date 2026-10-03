import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lcd_application/config.dart';
import 'package:lcd_application/helper.dart';
import 'package:lcd_application/background_service.dart';
import 'package:lcd_application/rest_communication.dart';
import 'package:lcd_application/pages/text_page.dart';
import 'package:lcd_application/pages/picture_page.dart';
import 'package:lcd_application/pages/lcd_simulation.dart';

void main() {
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LCD-Patch',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: const Color.fromARGB(255, 1, 78, 34)),
      ),
      home: const MyHomePage(title: 'LCD-Patch'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  RESTService rest = RESTService(requestServerURL);

  Timer? requestServerTimer;
  int requestServerInterval = 30;

  Timer? uploadBlockingTimer;
  int uploadBlockingTime = 60;
  int remainingUploadBlockingTime = 0;

  bool isAdmin = false;
  final passwordController = TextEditingController();
  bool useServer = false;

  bool isBackgroundReady = false;
  bool isBLEConnected = false;

  DisplayContext currentDisplayContext = DisplayContext.text;
  DisplayContext getCurrentContext() {
    return currentDisplayContext;
  }

  TftText enteredText = TftText(
    text: "",
    x: LcdSize.width.toInt() ~/ 2,
    y: LcdSize.height.toInt() ~/ 2 -18,
    font: 5,
    color: const Color.fromARGB(255, 0, 0, 0),
    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    align: TextAlign.center,
  );

  TftPicture? picture;

  late TftDisplay tft;
  
  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      FlutterForegroundTask.addTaskDataCallback(_onBackgroundData);
      _initForegroundTask();
      _startBackgroundService();
    }

    tft = TftDisplay(width: LcdSize.width.toInt(), height: LcdSize.height.toInt(), text: enteredText, getCurrentContext: getCurrentContext);
    startUploadBlockingTimer();
  }

  Future<void> _choosePicture() async {
    final ImagePicker picker = ImagePicker();

    final XFile? chosenFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (chosenFile != null) {
      final bytes = await chosenFile.readAsBytes();
      final ui.Image img = await bytesToImage(bytes);

      final imageWidth = img.width.toDouble();
      final imageHeight = img.height.toDouble();
      final scale = math.min(
        LcdSize.width.toInt() / imageWidth,
        LcdSize.height.toInt() / imageHeight,
      );

      picture = TftPicture(image: img, x: 0, y: 0, width: (imageWidth * scale).toInt(), height: (imageHeight * scale).toInt(), zoom: 1);
      _showLCD();
    }
  }

  void _showLCD() {
    switch (currentDisplayContext) {
      case DisplayContext.text: {
        tft.drawString(text: enteredText);
        setState(() {});
        break;
      }
      case DisplayContext.picture: {
        tft.drawBitmap(picture: picture!);
        setState(() {});
        break;
      }
    }
  }

  void _updateMCU() async {
    switch (currentDisplayContext) {
      case DisplayContext.text:
        final String textData = jsonEncode({
          "text": enteredText.text,
          "x": 0,
          "y": enteredText.y,
          "textSize": enteredText.font,
          "textColor": colorToRgb565(enteredText.color),
          "backgroundColor": colorToRgb565(enteredText.backgroundColor!),
        });

        if (kIsWeb) {
          final answer = await rest.uploadText(jsonEncodedTextData: textData,);
          if (!mounted) return;
          _uploadNotification(answer["queueCount"]);
        }
        else {
          if (isBackgroundReady) {
            FlutterForegroundTask.sendDataToTask({
              'command': BackgroundCommands.sendText,
              'data': textData,
            });
          }
        }
        break;

      case DisplayContext.picture:
        if (picture == null) {
          return;
        }
        final croppedImage = await cropImage(picture: picture!, dstWidth: LcdSize.width.toInt(), dstHeight: LcdSize.height.toInt());
        final pixelImage = await imageToPixels(croppedImage);
        final rgb565Image = await pixelsToRgb565(pixelImage);

        if (kIsWeb) {
          final answer = await rest.uploadPicture(picture: rgb565Image,);
          if (!mounted) return;
          _uploadNotification(answer["queueCount"]);
        }
        else {
          if (isBackgroundReady) {
            FlutterForegroundTask.sendDataToTask({
              'command': BackgroundCommands.sendPicture,
              'data': rgb565Image,
            });
          }
        }
        break;
    }
  }

  void startUploadBlockingTimer() {
    uploadBlockingTimer?.cancel();

    setState(() {
      remainingUploadBlockingTime = uploadBlockingTime;
    });

    uploadBlockingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (remainingUploadBlockingTime <= 1) {
          timer.cancel();

          setState(() {
            remainingUploadBlockingTime = 0;
          });
        } 
        else {
          setState(() {
            remainingUploadBlockingTime--;
          });
        }
      },
    );
  }
    
  void _initForegroundTask() {
    if (kIsWeb) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'lcd_background',
        channelName: 'LCD Background Service',
        channelDescription: 'BLE Connection and Request-Server polling',
        onlyAlertOnce: true,
      ),

      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),

      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(requestServerInterval*1000),
        allowWakeLock: true,
        allowWifiLock: true,
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
      ),
    );
  }

  Future<void> _startBackgroundService() async {
    if (kIsWeb) {
      return;
    }
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();

    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: [
        ForegroundServiceTypes.connectedDevice,
      ],
      notificationTitle: 'LCD-Patch',
      notificationText: 'LCD-Connection active',
      callback: startCallback,
    );
  }

  void _onBackgroundData(Object data) {
    if (!mounted) {
      return;
    }
    if (data is! Map) {
      return;
    }

    switch (data['type']) {
      case 'backgroundReady':
        setState(() {
          isBackgroundReady = true;
        });
        break;

      case 'bleStatus':
        setState(() {
          isBLEConnected = data['connected'];
        });
        break;

      case 'requestSent':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${data["queueCount"]} Requests in Queue"),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        break;

      case 'uploadResponse':
        _uploadNotification(data['queueCount']);
        break;

      case 'error':
        debugPrint('Background Error: ${data['message']}');
        break;
    }
  }

  void _uploadNotification(int queueCount) async {
      double waitingTime = (queueCount * requestServerInterval) / 60;
      String waitingTimeText = waitingTime.toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$queueCount Requests in Queue ($waitingTimeText minutes)"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .spaceBetween,
          children: [

            Column(
              mainAxisAlignment: .start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 3,
                    ),
                  ),
                  child: CustomPaint(
                    size: Size(LcdSize.width.toDouble(), LcdSize.height.toDouble()),
                    painter: TftPainter(tft),
                  ),
                ),
                const SizedBox(height: 10),

                if (currentDisplayContext == DisplayContext.text)
                  TextPage(
                    title: "TextPage",
                    enteredText: enteredText, 
                    showLCD: _showLCD, 
                  ),
                
                if (currentDisplayContext == DisplayContext.picture) 
                  PicturePage(
                    title: "PicturePage",
                    picture: picture,
                    showLCD: _showLCD,
                    choosePicture: _choosePicture,
                  ),

                const SizedBox(height: 10),
                
                ElevatedButton(
                  onPressed: remainingUploadBlockingTime == 0 
                  ? () {
                      if (!isAdmin) {
                        startUploadBlockingTimer();
                      }
                      _updateMCU();
                    }
                  : null,
                  child: Text(remainingUploadBlockingTime==0 ? "Upload" : "$remainingUploadBlockingTime seconds"),
                ),
              ],
            ),

            Stack(
              alignment: Alignment.center,
              children: [
                // Menü bleibt in der Mitte
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: DisplayContext.text.name,
                      label: const Text('Text'),
                      icon: const Icon(Icons.text_fields),
                    ),
                    ButtonSegment(
                      value: DisplayContext.picture.name,
                      label: const Text('Picture'),
                      icon: const Icon(Icons.image),
                    ),
                  ],
                  selected: {currentDisplayContext.name},
                  onSelectionChanged: (Set<String> newSubPage) {
                    setState(() {
                      currentDisplayContext =
                          DisplayContext.values.byName(newSubPage.first);
                    });
                  },
                ),

                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.bluetooth),
                        color: isBLEConnected ? Colors.green : Colors.red,
                        tooltip: 'Bluetooth',
                        onPressed: !isBackgroundReady ? null
                        : () async {
                          if (kIsWeb) {
                            return;
                          }

                          FlutterForegroundTask.sendDataToTask({
                            'command': BackgroundCommands.initBLE,
                          });
                        },
                      ),


                      if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.wifi),
                        color: useServer ? Colors.green : const ui.Color.fromARGB(255, 28, 29, 29),
                        tooltip: 'Server-Connection',
                        onPressed: !isBackgroundReady ? null
                        : () {
                          setState(() {
                            if (useServer) {
                              useServer = false;
                            } 
                            else {
                              useServer = true;
                            }
                          }); 

                          if (!kIsWeb) {
                            FlutterForegroundTask.sendDataToTask({
                              'command': BackgroundCommands.setServerMode,
                              'value': useServer,
                            });
                          }
                        }
                      )
                    ],
                  )
                ),

                Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                      tooltip: 'Admin',
                      icon: const Icon(Icons.admin_panel_settings),
                      color: isAdmin ? Colors.green : const ui.Color.fromARGB(255, 28, 29, 29),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Admin Login'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Abbrechen'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (passwordController.text == adminPassword) {
                                      setState(() {
                                        isAdmin = true;
                                        remainingUploadBlockingTime = 0;
                                      }); 
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('Login'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}