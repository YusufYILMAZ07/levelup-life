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
    this.requiresUpload = false,
  });

  /// `ChatMessage.mediaPathOrUrl` içine yazılacak değer.
  final String source;
  final ChatMediaType mediaType;
  final int durationSeconds;
  final String? thumbnailPath;

  /// Bulut yüklemesi için ham veri (yalnızca seçim anında bellekte).
  final Uint8List? bytes;

  /// Web'de 250 KB üstü medya `localStorage`'a gömülemez; önce Supabase
  /// Storage'a yüklenmesi gerekir.
  final bool requiresUpload;

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

  /// Web'de `localStorage` kotasını (genelde 5 MB) korumak için inline üst
  /// sınır. v5'te 6 MB'a kadar base64 gömülüyordu; bu, tüm oyun kaydını tek
  /// seferde bozabiliyordu.
  static const int maxInlineBytes = 250 * 1024;

  /// Hızlı yükleme ve düşük bellek kullanımı için video tavanı.
  static const int maxVideoBytes = 20 * 1024 * 1024;

  static const int maxVideoDurationSeconds = 45;

  /// Fotoğraf seç/çek. Kullanıcı vazgeçerse `null` döner.
  Future<PickedMedia?> pickImage({
    required ImageSource source,
    bool forAvatar = false,
    bool allowCloudUpload = false,
  }) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: forAvatar ? 900 : 1440,
        maxHeight: forAvatar ? 900 : 1440,
        imageQuality: forAvatar ? 88 : 78,
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
      final String mime = _mimeOf(file, 'image/jpeg');
      if (bytes.length <= maxInlineBytes) {
        return PickedMedia(
          source: 'data:$mime;base64,${base64Encode(bytes)}',
          mediaType: ChatMediaType.image,
          bytes: bytes,
        );
      }
      if (forAvatar) {
        throw const MediaPickException(
          'Profil fotoğrafı çok büyük (en fazla 250 KB). Daha küçük bir kare '
          'seç veya uygulamayı telefonda kullan.',
        );
      }
      if (!allowCloudUpload) {
        throw const MediaPickException(
          'Web’de büyük fotoğraflar için Supabase bağlantısı gerekli. '
          'Ayarlar → Bulut senkronunu kur ya da daha küçük bir fotoğraf seç.',
        );
      }
      // Önizleme için data URL bellekte tutulur; **kalıcı kayda yazılmaz**.
      // Görsel önce Supabase Storage'a yüklenir ve `localStorage` yalnızca
      // imzalı URL'yi saklar.
      return PickedMedia(
        source: 'data:$mime;base64,${base64Encode(bytes)}',
        mediaType: ChatMediaType.image,
        bytes: bytes,
        requiresUpload: true,
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

  /// Video seç/çek (en fazla 45 sn / 20 MB). Kullanıcı vazgeçerse `null`.
  ///
  /// [includeBytes] yalnızca bulut yüklemesi yapılacaksa `true` verilir;
  /// aksi hâlde büyük bir video belleğe alınmaz, yalnızca boyutu doğrulanır.
  Future<PickedMedia?> pickVideo({
    ImageSource source = ImageSource.gallery,
    bool includeBytes = false,
    bool allowCloudUpload = false,
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

    final int fileLength;
    try {
      fileLength = await file.length();
    } catch (_) {
      throw const MediaPickException('Video boyutu okunamadı, tekrar dene.');
    }
    if (fileLength > maxVideoBytes) {
      throw const MediaPickException(
        'Video çok büyük (en fazla 20 MB). Daha kısa bir video seç.',
      );
    }

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
      if (bytes.length > maxVideoBytes) {
        throw const MediaPickException(
          'Video çok büyük (en fazla 20 MB). Daha kısa bir video seç.',
        );
      }
    }

    if (kIsWeb) {
      final Uint8List webBytes = bytes!;
      final String mime = _mimeOf(file, 'video/mp4');
      if (webBytes.length <= maxInlineBytes) {
        return PickedMedia(
          source: 'data:$mime;base64,${base64Encode(webBytes)}',
          mediaType: ChatMediaType.video,
          bytes: webBytes,
        );
      }
      if (!allowCloudUpload) {
        throw const MediaPickException(
          'Web’de video göndermek için Supabase bağlantısı gerekli. '
          'Ayarlar → Bulut senkronunu kur ya da iPhone’da dene.',
        );
      }
      return PickedMedia(
        source: 'data:$mime;base64,${base64Encode(webBytes)}',
        mediaType: ChatMediaType.video,
        bytes: webBytes,
        requiresUpload: true,
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

  /// Profil fotoğrafı için galeriden kare seçer (Web'de inline sınır uygular).
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
