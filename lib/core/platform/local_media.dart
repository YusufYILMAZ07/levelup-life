import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'local_media_io.dart'
    if (dart.library.js_interop) 'local_media_web.dart';

export 'local_media_io.dart'
    if (dart.library.js_interop) 'local_media_web.dart';

/// `ChatMessage.mediaPathOrUrl` yerel dosya yolu mu?
///
/// `preset:`, `data:`, `http(s):` ve `blob:` dışındaki değerler cihazda
/// saklanan bir dosya kabul edilir.
bool isLocalMediaPath(String source) {
  final String value = source.trim();
  if (value.isEmpty) return false;
  return !value.startsWith('preset:') &&
      !value.startsWith('data:') &&
      !value.startsWith('http://') &&
      !value.startsWith('https://') &&
      !value.startsWith('blob:');
}

/// Yerel dosyadan görsel sağlayıcısı (Web'de `null`).
ImageProvider<Object>? localImageProvider(String path) =>
    createLocalImageProvider(path);

/// Yerel video denetleyicisi (Web'de ağ URL'si üzerinden).
VideoPlayerController createLocalVideoController(String path) =>
    buildLocalVideoController(path);
