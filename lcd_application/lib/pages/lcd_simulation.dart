import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum DisplayContext {
  text,
  picture,
}

class TftDisplay {
  final int width;
  final int height;

  final DisplayContext Function() getCurrentContext;

  TftText text;
  TftPicture? picture;

  TftDisplay({
    required this.width,
    required this.height,
    required this.getCurrentContext,
    required this.text,
  });

  void drawString({required TftText text}) {
    this.text = text;
  }

  void drawBitmap({required TftPicture picture}) {
    this.picture = picture;
  }
}


class TftPainter extends CustomPainter {
  final TftDisplay tft;

  TftPainter(this.tft);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / tft.width;
    final scaleY = size.height / tft.height;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    switch (tft.getCurrentContext()) {
      case DisplayContext.text: _drawString(canvas, tft.text); break;
      case DisplayContext.picture: {
        if (tft.picture != null) {
          _drawPicture(canvas, tft.picture!);
        }
        break;
      }
    }
    
    canvas.restore();
  }

  void _drawString(Canvas canvas, TftText tftText) {
    if (tftText.backgroundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          0,
          tft.width.toDouble(),
          tft.height.toDouble(),
        ),
        Paint()..color = tftText.backgroundColor!,
      );
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: tftText.text,
        style: TextStyle(
          color: tftText.color,
          fontSize: 8.0 * tftText.font,
        ),
      ),
      textAlign: tftText.align,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    double x = tftText.x.toDouble();

    if (tftText.align == TextAlign.center) {
      x -= textPainter.width / 2;
    } else if (tftText.align == TextAlign.right) {
      x -= textPainter.width;
    }

    textPainter.paint(
      canvas,
      Offset(x, tftText.y.toDouble()),
    );
  }

  void _drawPicture(Canvas canvas, TftPicture picture) {
    canvas.save();

    canvas.clipRect(const Rect.fromLTWH(0, 0, 320, 240));

    final width = picture.width * picture.zoom;
    final height = picture.height * picture.zoom;

    final destination = Rect.fromLTWH(
      picture.x.toDouble(),
      picture.y.toDouble(),
      width.toDouble(),
      height.toDouble(),
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
      Paint(),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TftPainter oldDelegate) {
    return true;
  }
}

class TftText {
  String text;
  int x;
  int y;
  int font;
  Color color;
  Color? backgroundColor;
  TextAlign align;

  TftText({
    required this.text,
    required this.x,
    required this.y,
    required this.font,
    required this.color,
    required this.backgroundColor,
    required this.align,
  });
}

class TftPicture {
  ui.Image image;
  int x;
  int y;
  int width;
  int height;
  int zoom;

  TftPicture({
    required this.image,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zoom,
  });
}