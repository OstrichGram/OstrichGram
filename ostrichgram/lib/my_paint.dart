import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Basic painter class.

class MyPainter60 extends CustomPainter {
  MyPainter60(this.svg, this.size);

  final DrawableRoot svg;
  final Size size;
  @override
  void paint(Canvas canvas, Size size) {
    svg.scaleCanvasToViewBox(canvas, Size(60.0, 60.0));
    svg.clipCanvasToViewBox(canvas);
    svg.draw(canvas, Rect.zero);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}


