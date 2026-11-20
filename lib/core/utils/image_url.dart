/// Sohbete gönderilecek görsel bağlantısını doğrular ve sadeleştirir.
///
/// Desteklenen biçimler:
/// * `http(s)://…` → uzak görsel (Supabase Storage, CDN, herkese açık link)
/// * `data:image/…;base64,…` → gömülü görsel
///
/// Diğer tüm şemalar (`ftp:`, `javascript:`, `file:`…) reddedilir; böylece
/// kullanıcı yanlışlıkla çalıştırılabilir bir metni fotoğraf gibi gönderemez.
/// Geçersiz girdide `null` döner.
String? normalizeImageUrl(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return null;

  if (value.startsWith('data:image/')) {
    final int comma = value.indexOf(',');
    if (comma <= 0) return null;
    final String metadata = value.substring(5, comma).toLowerCase();
    // [CouplePhoto] gömülü görselleri base64 olarak çözer.
    if (!metadata.contains('base64')) return null;
    return value;
  }

  final Uri? uri = Uri.tryParse(value);
  if (uri == null) return null;
  final String scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.trim().isEmpty) return null;
  return uri.toString();
}
