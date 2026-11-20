import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/local_media.dart';
import '../../core/theme/theme.dart';
import '../../services/app_settings.dart';

/// Yusuf / Ceyda avatarı.
///
/// Ayarlardan gerçek bir fotoğraf seçildiyse onu (data URL, https veya yerel
/// dosya), seçilmediyse partnerin renkli emoji rozetini gösterir.
class PartnerAvatar extends ConsumerWidget {
  const PartnerAvatar({
    required this.partnerId,
    this.size = 32,
    this.showRing = false,
    super.key,
  });

  final String partnerId;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String source = ref.watch(partnerAvatarProvider(partnerId));
    final Color accent = CouplePalette.colorOf(partnerId);

    return Semantics(
      label: '${CouplePalette.nameOf(partnerId)} profil fotoğrafı',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(showRing ? 2 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CouplePalette.softOf(partnerId, alpha: 0.16),
          border: showRing
              ? Border.all(color: accent.withValues(alpha: 0.55), width: 1.5)
              : null,
        ),
        child: ClipOval(
          child: source.trim().isEmpty
              ? _EmojiAvatar(partnerId: partnerId, size: size)
              : _image(source, size),
        ),
      ),
    );
  }

  Widget _image(String source, double size) {
    if (isLocalMediaPath(source)) {
      final ImageProvider<Object>? provider = localImageProvider(source);
      if (provider != null) {
        return Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _EmojiAvatar(partnerId: partnerId, size: size),
        );
      }
    }
    if (source.startsWith('data:image/')) {
      try {
        final int comma = source.indexOf(',');
        final String encoded = comma < 0 ? source : source.substring(comma + 1);
        return Image.memory(
          base64Decode(encoded),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _EmojiAvatar(partnerId: partnerId, size: size),
        );
      } on FormatException {
        return _EmojiAvatar(partnerId: partnerId, size: size);
      }
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _EmojiAvatar(partnerId: partnerId, size: size),
      );
    }
    return _EmojiAvatar(partnerId: partnerId, size: size);
  }
}

class _EmojiAvatar extends StatelessWidget {
  const _EmojiAvatar({required this.partnerId, required this.size});

  final String partnerId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: CouplePalette.softOf(partnerId, alpha: 0.14),
      child: Text(
        CouplePalette.emojiOf(partnerId),
        style: TextStyle(fontSize: size * 0.48),
      ),
    );
  }
}
