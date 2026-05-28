import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Germeen the black cat — the CuPet mascot.
///
/// Drawn as vector via [CustomPainter] so we don't need an image asset.
/// Pose is the brand reference: round face, perky ears, big yellow eyes,
/// little curly tail peeking from behind. Mood is set with [mood].
enum GermeenMood { sweet, sleepy, sassy, surprised }

class Germeen extends StatelessWidget {
  const Germeen({
    super.key,
    this.size = 96,
    this.mood = GermeenMood.sweet,
    this.background,
  });

  final double size;
  final GermeenMood mood;

  /// Optional yellow disc behind Germeen. Pass [Colors.transparent] to omit.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? CupetColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (bg != Colors.transparent)
            Container(
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupetColors.ink.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          CustomPaint(
            size: Size.square(size * 0.78),
            painter: _GermeenPainter(mood: mood),
          ),
        ],
      ),
    );
  }
}

class _GermeenPainter extends CustomPainter {
  _GermeenPainter({required this.mood});

  final GermeenMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fur = Paint()..color = CupetColors.ink;
    final eyeWhite = Paint()..color = CupetColors.primary;
    final eyePupil = Paint()..color = CupetColors.ink;
    final blush = Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.5);
    final whisker = Paint()
      ..color = CupetColors.ink
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final headCenter = Offset(w * 0.5, h * 0.58);
    final headRadius = w * 0.34;

    // ----- Tail (drawn first so the body covers its root) -----
    final tail = Path()
      ..moveTo(w * 0.78, h * 0.78)
      ..cubicTo(
        w * 0.95, h * 0.65,
        w * 1.02, h * 0.45,
        w * 0.84, h * 0.35,
      )
      ..cubicTo(
        w * 0.74, h * 0.30,
        w * 0.68, h * 0.40,
        w * 0.74, h * 0.48,
      );
    canvas.drawPath(
      tail,
      Paint()
        ..color = CupetColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ----- Body (chubby pear under the head) -----
    final bodyRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.92),
      width: w * 0.78,
      height: h * 0.50,
    );
    canvas.drawOval(bodyRect, fur);

    // ----- Ears -----
    final leftEar = Path()
      ..moveTo(headCenter.dx - headRadius * 0.85, headCenter.dy - headRadius * 0.55)
      ..lineTo(headCenter.dx - headRadius * 0.35, headCenter.dy - headRadius * 1.55)
      ..lineTo(headCenter.dx - headRadius * 0.05, headCenter.dy - headRadius * 0.75)
      ..close();
    final rightEar = Path()
      ..moveTo(headCenter.dx + headRadius * 0.85, headCenter.dy - headRadius * 0.55)
      ..lineTo(headCenter.dx + headRadius * 0.35, headCenter.dy - headRadius * 1.55)
      ..lineTo(headCenter.dx + headRadius * 0.05, headCenter.dy - headRadius * 0.75)
      ..close();
    canvas.drawPath(leftEar, fur);
    canvas.drawPath(rightEar, fur);

    // Inner ear (yellow tint)
    final earInner = Paint()..color = CupetColors.primary.withValues(alpha: 0.85);
    final leftInner = Path()
      ..moveTo(headCenter.dx - headRadius * 0.65, headCenter.dy - headRadius * 0.7)
      ..lineTo(headCenter.dx - headRadius * 0.40, headCenter.dy - headRadius * 1.30)
      ..lineTo(headCenter.dx - headRadius * 0.18, headCenter.dy - headRadius * 0.85)
      ..close();
    final rightInner = Path()
      ..moveTo(headCenter.dx + headRadius * 0.65, headCenter.dy - headRadius * 0.7)
      ..lineTo(headCenter.dx + headRadius * 0.40, headCenter.dy - headRadius * 1.30)
      ..lineTo(headCenter.dx + headRadius * 0.18, headCenter.dy - headRadius * 0.85)
      ..close();
    canvas.drawPath(leftInner, earInner);
    canvas.drawPath(rightInner, earInner);

    // ----- Head -----
    canvas.drawCircle(headCenter, headRadius, fur);

    // ----- Eyes -----
    final eyeY = headCenter.dy - headRadius * 0.10;
    final leftEye = Offset(headCenter.dx - headRadius * 0.42, eyeY);
    final rightEye = Offset(headCenter.dx + headRadius * 0.42, eyeY);

    if (mood == GermeenMood.sleepy) {
      final lid = Paint()
        ..color = CupetColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = headRadius * 0.10
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        leftEye + Offset(-headRadius * 0.18, 0),
        leftEye + Offset(headRadius * 0.18, 0),
        lid,
      );
      canvas.drawLine(
        rightEye + Offset(-headRadius * 0.18, 0),
        rightEye + Offset(headRadius * 0.18, 0),
        lid,
      );
    } else {
      final eyeR = headRadius * (mood == GermeenMood.surprised ? 0.26 : 0.22);
      canvas.drawCircle(leftEye, eyeR, eyeWhite);
      canvas.drawCircle(rightEye, eyeR, eyeWhite);

      final pupilR = mood == GermeenMood.sassy ? eyeR * 0.30 : eyeR * 0.55;
      final pupilOffset = mood == GermeenMood.sassy
          ? Offset(eyeR * 0.45, -eyeR * 0.25)
          : Offset.zero;
      canvas.drawOval(
        Rect.fromCenter(
          center: leftEye + pupilOffset,
          width: pupilR * 1.0,
          height: pupilR * (mood == GermeenMood.sassy ? 1.6 : 1.8),
        ),
        eyePupil,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: rightEye + pupilOffset,
          width: pupilR * 1.0,
          height: pupilR * (mood == GermeenMood.sassy ? 1.6 : 1.8),
        ),
        eyePupil,
      );

      // Sparkle
      canvas.drawCircle(
        leftEye + Offset(eyeR * 0.30, -eyeR * 0.30),
        eyeR * 0.18,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        rightEye + Offset(eyeR * 0.30, -eyeR * 0.30),
        eyeR * 0.18,
        Paint()..color = Colors.white,
      );
    }

    // ----- Blush cheeks -----
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - headRadius * 0.55,
            headCenter.dy + headRadius * 0.30),
        width: headRadius * 0.34,
        height: headRadius * 0.18,
      ),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx + headRadius * 0.55,
            headCenter.dy + headRadius * 0.30),
        width: headRadius * 0.34,
        height: headRadius * 0.18,
      ),
      blush,
    );

    // ----- Nose -----
    final nose = Path()
      ..moveTo(headCenter.dx - headRadius * 0.10,
          headCenter.dy + headRadius * 0.18)
      ..lineTo(headCenter.dx + headRadius * 0.10,
          headCenter.dy + headRadius * 0.18)
      ..lineTo(headCenter.dx, headCenter.dy + headRadius * 0.30)
      ..close();
    canvas.drawPath(nose, Paint()..color = CupetColors.primary);

    // ----- Mouth -----
    final mouth = Path();
    final mouthY = headCenter.dy + headRadius * 0.40;
    mouth.moveTo(headCenter.dx, headCenter.dy + headRadius * 0.30);
    mouth.lineTo(headCenter.dx, mouthY);
    if (mood == GermeenMood.surprised) {
      canvas.drawCircle(
        Offset(headCenter.dx, mouthY + headRadius * 0.05),
        headRadius * 0.08,
        Paint()..color = CupetColors.primary,
      );
    } else {
      mouth.relativeQuadraticBezierTo(
          -headRadius * 0.18, headRadius * 0.16, -headRadius * 0.28, 0);
      mouth.moveTo(headCenter.dx, mouthY);
      mouth.relativeQuadraticBezierTo(
          headRadius * 0.18, headRadius * 0.16, headRadius * 0.28, 0);
      canvas.drawPath(
        mouth,
        Paint()
          ..color = CupetColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = headRadius * 0.08
          ..strokeCap = StrokeCap.round,
      );
    }

    // ----- Whiskers -----
    for (final dy in [-headRadius * 0.05, headRadius * 0.10]) {
      canvas.drawLine(
        Offset(headCenter.dx - headRadius * 0.30,
            headCenter.dy + headRadius * 0.25 + dy),
        Offset(headCenter.dx - headRadius * 0.85,
            headCenter.dy + headRadius * 0.20 + dy),
        whisker..color = CupetColors.primary,
      );
      canvas.drawLine(
        Offset(headCenter.dx + headRadius * 0.30,
            headCenter.dy + headRadius * 0.25 + dy),
        Offset(headCenter.dx + headRadius * 0.85,
            headCenter.dy + headRadius * 0.20 + dy),
        whisker..color = CupetColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GermeenPainter old) => old.mood != mood;
}
