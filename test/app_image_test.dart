import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/shared/widgets/app_image.dart';

void main() {
  testWidgets('AppImage sizes infinite thumbnails from layout constraints',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1000, 900),
            devicePixelRatio: 1,
          ),
          child: const Center(
            child: SizedBox(
              width: 120,
              height: 80,
              child: AppImage(
                imageUrl: 'https://example.com/product.jpg',
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;

    expect(provider, isA<ResizeImage>());
    final resizeImage = provider as ResizeImage;
    expect(resizeImage.width, 192);
    expect(resizeImage.height, 192);
  });
}
