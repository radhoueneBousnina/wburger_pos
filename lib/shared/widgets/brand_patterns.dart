import 'package:flutter/material.dart';

class BrandBlobPainter extends CustomPainter {
  final Color color;
  BrandBlobPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.5, 0);
    path.cubicTo(w * 0.9, 0, w, h * 0.3, w * 0.95, h * 0.6);
    path.cubicTo(w * 0.9, h * 0.9, w * 0.7, h, w * 0.4, h * 0.9);
    path.cubicTo(w * 0.1, h * 0.8, 0, h * 0.6, 0.05 * w, h * 0.35);
    path.cubicTo(0.1 * w, h * 0.1, w * 0.1, 0, w * 0.5, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandCheckerPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  const BrandCheckerPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 24.0;
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    int col = 0;
    for (double x = 0; x < size.width + tileSize; x += tileSize) {
      int row = 0;
      for (double y = 0; y < size.height; y += tileSize) {
        final paint = ((col + row) % 2 == 0) ? paint1 : paint2;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1.5, y + 1.5, tileSize - 3, tileSize - 3),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, paint);
        row++;
      }
      col++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
