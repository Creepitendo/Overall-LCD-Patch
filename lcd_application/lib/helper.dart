import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lcd_application/config.dart';
import 'package:lcd_application/pages/lcd_simulation.dart';

enum MoveDirection {
  up,
  down,
  left,
  right,
}

class DirectionPad extends StatelessWidget {
  final Set<MoveDirection> directions;
  final void Function(MoveDirection direction) onStart;
  final VoidCallback onStop;

  const DirectionPad({
    super.key,
    required this.directions,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (directions.contains(MoveDirection.up))
          _arrowButton(
            context,
            Icons.arrow_upward,
            MoveDirection.up,
          ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (directions.contains(MoveDirection.left))
              _arrowButton(
                context,
                Icons.arrow_back,
                MoveDirection.left,
              ),

            if (directions.contains(MoveDirection.left) &&
                directions.contains(MoveDirection.right))
              const SizedBox(width: 40),

            if (directions.contains(MoveDirection.right))
              _arrowButton(
                context,
                Icons.arrow_forward,
                MoveDirection.right,
              ),
          ],
        ),

        if (directions.contains(MoveDirection.down))
          _arrowButton(
            context,
            Icons.arrow_downward,
            MoveDirection.down,
          ),
      ],
    );
  }

  Widget _arrowButton(
    BuildContext context,
    IconData icon,
    MoveDirection direction,
  ) {
    return GestureDetector(
      onTapDown: (_) => onStart(direction),
      onTapUp: (_) => onStop(),
      onTapCancel: onStop,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
      ),
    );
  }
}

int colorToRgb565(Color color) {
  final r = (color.r * 31).round();
  final g = (color.g * 63).round();
  final b = (color.b * 31).round();

  return (r << 11) | (g << 5) | b;
}

Future<List<int>> pixelsToRgb565(List<Color> pixels) async {
  List<int> res = [];
  for (Color pixel in pixels) {
    res.add(colorToRgb565(pixel));
  }
  return res;
}

Future<List<Color>> imageToPixels(ui.Image image) async {
  final byteData = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );

  if (byteData == null) {
    throw Exception('Pixel konnten nicht gelesen werden');
  }

  final bytes = byteData.buffer.asUint8List();

  final pixels = <Color>[];

  for (int i = 0; i < image.width * image.height; i++) {
    final r = bytes[i * 4];
    final g = bytes[i * 4 + 1];
    final b = bytes[i * 4 + 2];
    final a = bytes[i * 4 + 3];

    pixels.add(Color.fromARGB(a, r, g, b));
  }

  return pixels;
}

Future<ui.Image> bytesToImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<ui.Image> cropImage({
  required TftPicture picture,
  required int dstWidth,
  required int dstHeight,
}) async {

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.clipRect(Rect.fromLTWH(0, 0, dstWidth.toDouble(), dstHeight.toDouble()));

  final destination = Rect.fromLTWH(
    picture.x.toDouble(),
    picture.y.toDouble(),
    picture.width.toDouble() * picture.zoom,
    picture.height.toDouble() * picture.zoom,
  );

  final source = Rect.fromLTWH(
    0,
    0,
    picture.image.width.toDouble(),
    picture.image.height.toDouble(),
  );

  canvas.drawImageRect(
    picture.image,
    source,
    destination,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );

  final finalPicture = recorder.endRecording();

  return finalPicture.toImage(dstWidth, dstHeight);
}