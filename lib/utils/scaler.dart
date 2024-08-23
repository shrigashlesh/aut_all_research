import 'package:flutter/material.dart';

Future<(double, double)> calScaleFact(Size orgSize, GlobalKey key) async {
  Rect? bounds = key.globalPaintBounds(null);
  // Retry mechanism
  while (bounds == null || bounds.width == 0) {
    await Future.delayed(const Duration(milliseconds: 10));
    bounds = key.globalPaintBounds(null);
  }
  final double heightInDevice = bounds.size.height;
  final double widthInDevice = bounds.size.width;

  double imageOriginalHeight = orgSize.height;
  double imageOriginalWidth = orgSize.width;

  final scaleX = imageOriginalWidth / widthInDevice;
  final scaleY = imageOriginalHeight / heightInDevice;
  return (scaleX, scaleY);
}

extension GlobalKeyExtension on GlobalKey {
  Rect? globalPaintBounds(RenderObject? ancestor) {
    final renderObject = currentContext?.findRenderObject();
    if (renderObject != null) {
      final translation =
          renderObject.getTransformTo(ancestor).getTranslation();
      final offset = Offset(translation.x, translation.y);
      return renderObject.paintBounds.shift(offset);
    }
    return null;
  }
}
