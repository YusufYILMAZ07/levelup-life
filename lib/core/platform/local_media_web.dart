import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Web: dosya sistemi yok; medya data URL / blob URL olarak taşınır.
ImageProvider<Object>? createLocalImageProvider(String path) => null;

VideoPlayerController buildLocalVideoController(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));

Future<String?> persistMediaFile(String sourcePath, String fileName) async =>
    null;
