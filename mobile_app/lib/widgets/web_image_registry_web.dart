import 'package:flutter/widgets.dart';
import 'dart:ui_web' as ui_web;
import 'package:universal_html/html.dart' as html;

void registerWebImage(String viewId, String url, BoxFit fit) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final html.ImageElement img = html.ImageElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain';
      return img;
    },
  );
}
