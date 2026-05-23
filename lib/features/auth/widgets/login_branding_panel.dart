part of '../screens/login_screen.dart';

class _BrandingPanel extends StatelessWidget {
  const _BrandingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blue,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Positioned(
            top: -110,
            right: -90,
            child: CustomPaint(
              size: const Size(280, 280),
              painter: _BlobPainter(color: AppColors.yellow, rotation: -0.3),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 70,
              child: CustomPaint(painter: _CheckerboardPainter()),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: CustomPaint(
              size: const Size(260, 260),
              painter: _BlobPainter(color: AppColors.yellow, rotation: 1.2),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoHeight = (constraints.maxHeight * 0.30)
                    .clamp(82.0, 190.0)
                    .toDouble();
                final firstGap =
                    (constraints.maxHeight * 0.04).clamp(8.0, 20.0).toDouble();
                final secondGap =
                    (constraints.maxHeight * 0.08).clamp(10.0, 48.0).toDouble();
                final taglineFont =
                    constraints.maxWidth < 360 || constraints.maxHeight < 300
                        ? 11.0
                        : 14.0;

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logos/logo_yellow.png',
                        height: logoHeight,
                        cacheHeight: (logoHeight *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          'W',
                          style: TextStyle(
                            fontSize: logoHeight * 0.42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.yellow,
                          ),
                        ),
                      ),
                      SizedBox(height: firstGap),
                      Text(
                        'A WIN IN EVERY BITE',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.yellow,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          fontSize: taglineFont,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: secondGap),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.point_of_sale_rounded,
                              color: AppColors.blue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'POS Terminal',
                              style: AppTextStyles.titleSm.copyWith(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  final double rotation;

  const _BlobPainter({required this.color, this.rotation = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.width / 2, -size.height / 2);

    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, h * 0.05);
    path.cubicTo(w * 0.85, h * 0.0, w * 1.0, h * 0.3, w * 0.95, h * 0.55);
    path.cubicTo(w * 0.9, h * 0.8, w * 0.7, h * 1.0, w * 0.45, h * 0.96);
    path.cubicTo(w * 0.2, h * 0.92, w * 0.0, h * 0.75, w * 0.05, h * 0.5);
    path.cubicTo(w * 0.1, h * 0.25, w * 0.15, h * 0.1, w * 0.5, h * 0.05);
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 20.0;
    const gap = 4.0;
    const radius = 4.0;
    final whitePaint = Paint()..color = Colors.white.withValues(alpha: 0.96);
    final yellowPaint = Paint()
      ..color = AppColors.yellow.withValues(alpha: 0.98);
    final pitch = tileSize + gap;
    final rows = (size.height / pitch).ceil();
    final columns = (size.width / pitch).ceil() + 1;
    final yOffset = (size.height - (rows * tileSize + (rows - 1) * gap)) / 2;

    for (var row = 0; row < rows; row += 1) {
      for (var column = 0; column < columns; column += 1) {
        final x = column * pitch - gap;
        final y = yOffset + row * pitch;
        final paint = (column + row).isEven ? whitePaint : yellowPaint;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, tileSize, tileSize),
            const Radius.circular(radius),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
