import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lcd_application/helper.dart';
import 'package:lcd_application/pages/lcd_simulation.dart';

class PicturePage extends StatefulWidget {
  final TftPicture? picture;
  final VoidCallback showLCD;
  final Future<void> Function() choosePicture;

  const PicturePage({
    super.key, 
    required this.title,
    required this.picture,
    required this.showLCD,
    required this.choosePicture,
  });

  final String title;

  @override
  State<PicturePage> createState() => _PicturePageState();
}

class _PicturePageState extends State<PicturePage> {
  Timer? _moveTimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: .center,
      children: [
        ElevatedButton.icon(
          onPressed: widget.choosePicture,
          icon: const Icon(Icons.photo_library),
          label: const Text('Choose Picture'),
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: .center,
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onInverseSurface
                  ),
                ],
                borderRadius: BorderRadius.circular(48),
                border: Border.all(
                  color: Color.fromARGB(110, 136, 136, 136),
                  width: 1,
                ),
              ),
              child:
                DirectionPad(
                  directions: {
                    MoveDirection.up,
                    MoveDirection.down,
                    MoveDirection.left,
                    MoveDirection.right,
                  },
                  onStart: (direction) {
                    if (widget.picture == null) return;
                    switch (direction) {
                      case MoveDirection.down: widget.picture!.y--; break;
                      case MoveDirection.up: widget.picture!.y++; break;
                      case MoveDirection.left: widget.picture!.x++; break;
                      case MoveDirection.right: widget.picture!.x--; break;
                    }
                    widget.showLCD();

                    _moveTimer = Timer.periodic(
                      Duration(milliseconds: (5 / (widget.picture!.zoom * 0.5)).toInt()),
                      (_) {
                        switch (direction) {
                          case MoveDirection.down: widget.picture!.y--; break;
                          case MoveDirection.up: widget.picture!.y++; break;
                          case MoveDirection.left: widget.picture!.x++; break;
                          case MoveDirection.right: widget.picture!.x--; break;
                        }
                        widget.showLCD();
                      },
                    );
                  },
                  onStop: () {
                    _moveTimer?.cancel();
                    _moveTimer = null;
                  },
                ),
            ),

            const SizedBox(width: 40),

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
              child:
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add, 
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        if (widget.picture == null) return;
                        widget.picture!.zoom++;
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        if (widget.picture == null) return;
                        if (widget.picture!.zoom > 1) widget.picture!.zoom--;
                      },
                    ),
                  ],
                )
            ),
          ],
        )
      ],
    );
  }
}
