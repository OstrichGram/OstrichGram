// Experimental homegrown deterministic facepainter.  Not used -- instead we have MultiAvatar,
// but cool code to revisit someday in case we want to make our own avatar icons.

import 'dart:math';
import 'package:flutter/material.dart';

class FacePainter extends CustomPainter {
  final String id;

  FacePainter({required this.id});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final eyeRadius = 6.0;
    final noseRadius = 2.0;
    final mouthWidth = 24.0;
    final mouthHeight = 14.0;

    // Generate a seed from the ID
    final seed = id.codeUnits.reduce((acc, element) => acc ^ element);
    final random = Random(seed);

    // Draw background
    final backgroundPaint = Paint()..color = Color.fromRGBO(random.nextInt(255), random.nextInt(255), random.nextInt(255), 1);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, size.height), backgroundPaint);

    // Draw left eye
    final leftEyeDx = centerX - 12 + random.nextDouble() * 6 - 3;
    final leftEyeDy = centerY - 10 + random.nextDouble() * 6 - 3;
    final leftEyePaint = Paint()..color = Color.fromRGBO(random.nextInt(255), random.nextInt(255), random.nextInt(255), 1);
    canvas.drawCircle(Offset(leftEyeDx, leftEyeDy), eyeRadius, leftEyePaint);

    // Draw right eye
    final rightEyeDx = centerX + 12 + random.nextDouble() * 6 - 3;
    final rightEyeDy = centerY - 10 + random.nextDouble() * 6 - 3;
    final rightEyePaint = Paint()..color = Color.fromRGBO(random.nextInt(255), random.nextInt(255), random.nextInt(255), 1);
    canvas.drawCircle(Offset(rightEyeDx, rightEyeDy), eyeRadius, rightEyePaint);

    // Draw nose
    final noseDx = centerX + random.nextDouble() * 4 - 2;
    final noseDy = centerY + random.nextDouble() * 4 - 2;
    final nosePaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(noseDx, noseDy), noseRadius, nosePaint);

    // Draw mouth
    final path = Path();
    path.moveTo(centerX - mouthWidth / 2, centerY + 10);
    path.quadraticBezierTo(
        centerX,
        centerY + 10 + random.nextDouble() * mouthHeight,
        centerX + mouthWidth / 2,
        centerY + 10);
    final mouthPaint = Paint()..color = Colors.black;
    canvas.drawPath(path, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
