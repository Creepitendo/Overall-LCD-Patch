import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lcd_application/config.dart';
import 'package:lcd_application/helper.dart';
import 'package:lcd_application/ble_communication.dart';
import 'package:lcd_application/pages/text_page.dart';
import 'package:lcd_application/pages/picture_page.dart';
import 'package:lcd_application/pages/lcd_simulation.dart';

void main() {
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
  BLEConnection ble = BLEConnection();

  bool isAdmin = false;
  final passwordController = TextEditingController();
  bool useServer = false;

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

    tft = TftDisplay(width: LcdSize.width.toInt(), height: LcdSize.height.toInt(), text: enteredText, getCurrentContext: getCurrentContext);
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
        ble.sendText(textData);
        break;
      case DisplayContext.picture:
        if (picture == null) {
          return;
        }
        final croppedImage = await cropImage(picture: picture!, dstWidth: LcdSize.width.toInt(), dstHeight: LcdSize.height.toInt());
        final pixelImage = await imageToPixels(croppedImage);
        final rgb565Image = await pixelsToRgb565(pixelImage);
        ble.sendPicture(rgb565Image);
        break;
    }
    
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
                  onPressed: () {
                    _updateMCU();
                  },
                  child: const Text("Upload"),
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
                      ValueListenableBuilder<bool>(
                        valueListenable: ble.isConnected,
                        builder: (context, connected, child) {
                          return IconButton(
                            icon: const Icon(Icons.bluetooth),
                            color: connected ? Colors.green : Colors.red,
                            tooltip: 'Bluetooth',
                            onPressed: () {
                              if (!connected) {
                                ble.init();
                              }
                            },
                          );
                        },
                      ),

                      if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.wifi),
                        color: useServer ? Colors.green : const ui.Color.fromARGB(255, 28, 29, 29),
                        tooltip: 'Server-Connection',
                        onPressed: () {
                          setState(() {
                            if (useServer) {
                              useServer = false;
                            } else {
                              useServer = true;
                            }
                          }); 
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