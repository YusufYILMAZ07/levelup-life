import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/platform/local_media.dart';
import '../domain/entities/chat_message.dart';

/// Kamera / galeriden seçilen medyanın uygulama modeline hazır hali.
final class PickedMedia {
  const PickedMedia({
    required this.source,
    required this.mediaType,
    this.durationSeconds = 0,
    this.thumbnailPath,
    this.bytes,
  });

  /// `ChatMessage.mediaPathOrUrl` içine yazılacak değer.
  final String source;
  final ChatMediaType mediaType;
  final int durationSeconds;
  final String? thumbnailPath;

  /// Bulut yüklemesi için ham veri (yalnızca seçim anında bellekte).
  final Uint8List? bytes;

  bool get isVideo => mediaType == ChatMediaType.video;
}

/// Kullanıcıya gösterilecek, Türkçe ve sakin medya hataları.
final class MediaPickException implements Exception {
  const MediaPickException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Gerçek telefon kamerası + galeri köprüsü.
///
/// * **Mobil (iOS / Android):** seçilen dosya uygulamanın `media/` klasörüne
///   kopyalanır ve kalıcı yol döner.
/// * **Web (Chrome):** dosya `base64` **data URL**'ye çevrilir; böylece
///   `Image.memory` / `video_player` ek plugin olmadan çalışır.
final class MediaService {
  MediaService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Web'de localStorage taşma riskine karşı güvenli üst sınır.
  static const int maxInlineBytes = 6 * 1024 * 1024;

  static const int maxVideoDurationSeconds = 60;

  /// Fotoğraf seç/çek. Kullanıcı vazgeçerse `null` döner.
  Future<PickedMedia?> pickImage({
    required ImageSource source,
    bool forAvatar = false,
  }) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: forAvatar ? 900 : 1800,
        maxHeight: forAvatar ? 900 : 1800,
        imageQuality: forAvatar ? 88 : 82,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {
      throw const MediaPickException(
        'Kamera ya da galeri açılamadı. İzinleri kontrol edip tekrar dene.',
      );
    }
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const MediaPickException('Fotoğraf okunamadı, tekrar dener misin?');
    }
    if (bytes.isEmpty) {
      throw const MediaPickException('Fotoğraf boş görünüyor.');
    }

    if (kIsWeb) {
      if (bytes.length > maxInlineBytes) {
        throw const MediaPickException(
          'Fotoğraf çok büyük (en fazla 6 MB). Daha küçük bir kare seç.',
        );
      }
      final String mime = _mimeOf(file, 'image/jpeg');
      return PickedMedia(
        source: 'data:$mime;base64,${base64Encode(bytes)}',
        mediaType: ChatMediaType.image,
        bytes: bytes,
      );
    }

    final String stored =
        await persistMediaFile(
          file.path,
          'img_${DateTime.now().microsecondsSinceEpoch}.${_extensionOf(file, 'jpg')}',
        ) ??
        file.path;
    return PickedMedia(
      source: stored,
      mediaType: ChatMediaType.image,
      bytes: bytes,
    );
  }

  /// Video seç/çek (en fazla 60 sn). Kullanıcı vazgeçerse `null` döner.
  ///
  /// [includeBytes] yalnızca bulut yüklemesi yapılacaksa `true` verilir;
  /// aksi hâlde 60 sn'lik bir video belleğe alınmaz.
  Future<PickedMedia?> pickVideo({
    ImageSource source = ImageSource.gallery,
    bool includeBytes = false,
  }) async {
    final XFile? file;
    try {
      file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: maxVideoDurationSeconds),
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {
      throw const MediaPickException(
        'Video seçilemedi. Kamera/galeri iznini kontrol et.',
      );
    }
    if (file == null) return null;

    Uint8List? bytes;
    if (kIsWeb || includeBytes) {
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        throw const MediaPickException('Video okunamadı, tekrar dener misin?');
      }
      if (bytes.isEmpty) {
        throw const MediaPickException('Video boş görünüyor.');
      }
    }

    if (kIsWeb) {
      final Uint8List webBytes = bytes!;
      if (webBytes.length > maxInlineBytes) {
        throw const MediaPickException(
          'Video çok büyük (en fazla 6 MB). Daha kısa bir video seç.',
        );
      }
      final String mime = _mimeOf(file, 'video/mp4');
      return PickedMedia(
        source: 'data:$mime;base64,${base64Encode(webBytes)}',
        mediaType: ChatMediaType.video,
        bytes: webBytes,
      );
    }

    final String stored =
        await persistMediaFile(
          file.path,
          'vid_${DateTime.now().microsecondsSinceEpoch}.${_extensionOf(file, 'mp4')}',
        ) ??
        file.path;
    return PickedMedia(
      source: stored,
      mediaType: ChatMediaType.video,
      bytes: bytes,
    );
  }

  /// Profil fotoğrafı için galeriden kare seçer.
  Future<String?> pickAvatar() async {
    final PickedMedia? media = await pickImage(
      source: ImageSource.gallery,
      forAvatar: true,
    );
    return media?.source;
  }

  static String _extensionOf(XFile file, String fallback) {
    final String name = file.name;
    final int dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return fallback;
    final String ext = name.substring(dot + 1).toLowerCase();
    return ext.length > 5 ? fallback : ext;
  }

  static String _mimeOf(XFile file, String fallback) {
    final String type = file.mimeType ?? '';
    if (type.contains('/')) return type;
    final String ext = _extensionOf(file, '');
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'm4v' => 'video/x-m4v',
      _ => fallback,
    };
  }
}
