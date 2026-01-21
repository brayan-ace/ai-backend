import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../widgets/new_app_icon.dart';

/// Utility to generate app icon as image
class IconGenerator {
  static Future<ui.Image> generateAppIcon(double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Create the widget
    final widget = NewAppIcon(size: size, withGlow: false);
    
    // Render to image
    final renderObject = widget.createRenderObject(
      RenderObjectView(
        configuration: View.of(
          RenderObjectToWidgetAdapter(
            container: RenderObjectToWidgetAdapter(
              container: GlobalKey(),
              child: widget,
            ),
          ),
        ),
      ),
    );
    
    // Paint the widget
    renderObject.paint(PaintingContext(canvas, Offset.zero), Offset.zero);
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    picture.dispose();
    
    return image;
  }
}
