import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lcd_application/helper.dart';
import 'package:lcd_application/pages/lcd_simulation.dart';

class TextPage extends StatefulWidget {
  final TftText enteredText;
  final VoidCallback showLCD;

  const TextPage({
    super.key, 
    required this.title,
    required this.enteredText,
    required this.showLCD,
  });

  final String title;

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  Timer? _moveTimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: "Enter Text",
          ),
          onChanged: (text) {
            if (text.isNotEmpty) {
              widget.enteredText.text = text;
              widget.showLCD();
            }
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: .center,
          children: [
            ElevatedButton(
              onPressed: () {
                Color selectedColor = widget.enteredText.color;

                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Choose Text Color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: selectedColor,
                          onColorChanged: (Color color) {
                            selectedColor = color;
                          },
                          enableAlpha: false,
                          labelTypes: const [],
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            setState(() {
                              widget.enteredText.color = selectedColor;
                            });
                            Navigator.of(context).pop();
                            widget.showLCD();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('Text Color'),
            ),

            const SizedBox(width: 10),

            DropdownButton<int>(
              value: widget.enteredText.font,
              items: const [
                DropdownMenuItem(value: 1, child: Text("1")),
                DropdownMenuItem(value: 2, child: Text("2")),
                DropdownMenuItem(value: 3, child: Text("3")),
                DropdownMenuItem(value: 4, child: Text("4")),
                DropdownMenuItem(value: 5, child: Text("5")),
                DropdownMenuItem(value: 6, child: Text("6")),
                DropdownMenuItem(value: 7, child: Text("7")),
                DropdownMenuItem(value: 8, child: Text("8")),
                DropdownMenuItem(value: 9, child: Text("9")),
              ],
              onChanged: (value) {
                setState(() {
                  widget.enteredText.font = value!;
                });
              },
            ),

            const SizedBox(width: 10),

            ElevatedButton(
              onPressed: () {
                Color selectedColor = widget.enteredText.backgroundColor!;

                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Choose Background Color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: selectedColor,
                          onColorChanged: (Color color) {
                            selectedColor = color;
                          },
                          enableAlpha: false,
                          labelTypes: const [],
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            setState(() {
                              widget.enteredText.backgroundColor = selectedColor;
                            });
                            Navigator.of(context).pop();
                            widget.showLCD();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('Background'),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.onInverseSurface
              ),
            ],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color.fromARGB(110, 136, 136, 136),
              width: 1,
            ),
          ),
          child: DirectionPad(
              directions: {
                MoveDirection.up,
                MoveDirection.down,
              },
              onStart: (direction) {
                switch (direction) {
                  case MoveDirection.down: widget.enteredText.y++; break;
                  case MoveDirection.up: widget.enteredText.y--; break;
                  default: break;
                }
                widget.showLCD();

                _moveTimer = Timer.periodic(
                  Duration(milliseconds: 15),
                  (_) {
                    switch (direction) {
                      case MoveDirection.down: widget.enteredText.y++; break;
                      case MoveDirection.up: widget.enteredText.y--; break;
                      default: break;
                    }
                    widget.showLCD();
                  },
                );
              },
              onStop: () {
                _moveTimer?.cancel();
                _moveTimer = null;
              },
            )
        ),
      ]
    );
  }
}