import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// iOS / Android: gerçek cihaz dosyaları.
ImageProvider<Object>? createLocalImageProvider(String path) =>
    FileImage(File(path));

VideoPlayerController buildLocalVideoController(String path) =>
    VideoPlayerController.file(File(path));

/// Seçilen medyayı uygulamanın kalıcı `media/` klasörüne kopyalar.
Future<String?> persistMediaFile(String sourcePath, String fileName) async {
  try {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory folder = Directory('${documents.path}/media');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final String target = '${folder.path}/$fileName';
    if (sourcePath == target) return target;
    await File(sourcePath).copy(target);
    return target;
  } catch (_) {
    // Kopyalanamazsa geçici yol ile devam edilir; uygulama çökmez.
    return null;
  }
}
