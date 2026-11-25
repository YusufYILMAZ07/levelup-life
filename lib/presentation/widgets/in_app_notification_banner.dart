import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/pin_lock_controller.dart';
import '../../application/shell_controller.dart';
import '../../core/theme/theme.dart';

/// Uygulama içi bildirimin görsel türü.
enum InAppNotificationKind { message, photo, video, nudge, capsule, test, sent }

/// Tek bir uygulama içi bildirim.
final class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.emoji,
    required this.kind,
    required this.createdAt,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String emoji;
  final InAppNotificationKind kind;
  final DateTime createdAt;
  final String? payload;
}

/// iOS'taki üst bildirim merkezinin Flutter karşılığı.
///
/// OS bildirimi Web'de çalışmasa da (ve iOS ön planda bazen banner'ı gizlese
/// de) bu merkez **her platformda** anlık görsel geri bildirim verir. Aynı anda
/// tek bildirim gösterilir; yenisi gelirse önceki nazikçe değiştirilir.
final class InAppNotificationCenter extends ChangeNotifier {
  InAppNotificationCenter._();

  static final InAppNotificationCenter instance = InAppNotificationCenter._();

  static const Duration visibleFor = Duration(seconds: 5);

  InAppNotification? _current;
  Timer? _hideTimer;
  int _nextId = 1;

  InAppNotification? get current => _current;

  void show({
    required String title,
    required String body,
    String emoji = '💌',
    InAppNotificationKind kind = InAppNotificationKind.message,
    String? payload,
    Duration duration = visibleFor,
  }) {
    _hideTimer?.cancel();
    _current = InAppNotification(
      id: _nextId++,
      title: title.trim(),
      body: body.trim(),
      emoji: emoji,
      kind: kind,
      createdAt: DateTime.now(),
      payload: payload,
    );
    notifyListeners();
    unawaited(_haptic());
    _hideTimer = Timer(duration, dismiss);
  }

  void dismiss() {
    if (_current == null) return;
    _hideTimer?.cancel();
    _hideTimer = null;
    _current = null;
    notifyListeners();
  }

  /// Testler arasında durum sızmasını önler.
  @visibleForTesting
  void reset() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _current = null;
    notifyListeners();
  }

  Future<void> _haptic() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Masaüstü / test ortamında dokunma motoru olmayabilir.
    }
  }
}

/// Tüm `MaterialApp` içeriğini saran global bildirim katmanı.
///
/// `MaterialApp.builder` içine yerleştirilir; böylece hangi sekme açık olursa
/// olsun banner en üstte görünür ve dokunulduğunda Sohbet sekmesi açılır.
class InAppNotificationHost extends ConsumerStatefulWidget {
  const InAppNotificationHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<InAppNotificationHost> createState() =>
      _InAppNotificationHostState();
}

class _InAppNotificationHostState extends ConsumerState<InAppNotificationHost> {
  InAppNotification? _last;
  bool _visible = false;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    InAppNotificationCenter.instance.addListener(_onNotification);
    _last = InAppNotificationCenter.instance.current;
    _visible = _last != null;
  }

  @override
  void dispose() {
    InAppNotificationCenter.instance.removeListener(_onNotification);
    _clearTimer?.cancel();
    super.dispose();
  }

  void _onNotification() {
    final InAppNotification? next = InAppNotificationCenter.instance.current;
    _clearTimer?.cancel();
    // PIN kilitliyken hiçbir mesaj/içerik banner'ı gösterilmez.
    if (ref.read(pinLockProvider)) {
      setState(() {
        _last = null;
        _visible = false;
      });
      return;
    }
    if (next != null) {
      setState(() {
        _last = next;
        _visible = true;
      });
      return;
    }
    setState(() => _visible = false);
    _clearTimer = Timer(const Duration(milliseconds: 340), () {
      if (!mounted) return;
      setState(() {
        if (!_visible) _last = null;
      });
    });
  }

  void _openChat() {
    InAppNotificationCenter.instance.dismiss();
    ref.read(shellTabProvider.notifier).goToChat();
  }

  @override
  Widget build(BuildContext context) {
    // Kilit aniden devreye girerse (arka plandan dönüş) anlık banner'ı sök.
    ref.listen<bool>(pinLockProvider, (bool? previous, bool locked) {
      if (!locked) return;
      _clearTimer?.cancel();
      if (_last != null || _visible) {
        setState(() {
          _last = null;
          _visible = false;
        });
      }
      InAppNotificationCenter.instance.dismiss();
    });

    final InAppNotification? item = ref.watch(pinLockProvider) ? null : _last;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (item != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, -1.35),
                duration: AppMotion.base,
                curve: _visible ? AppMotion.emphasize : AppMotion.exit,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: AppMotion.fast,
                  child: _NotificationCard(
                    notification: item,
                    onTap: _openChat,
                    onClose: InAppNotificationCenter.instance.dismiss,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onClose,
  });

  final InAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: true,
      label: '${notification.title}. ${notification.body}',
      child: Material(
        key: const Key('in-app-notification-banner'),
        color: Colors.transparent,
        borderRadius: AppRadii.lgAll,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppGradients.aura(AppColors.primary, peakOpacity: 0.10),
            borderRadius: AppRadii.lgAll,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
            boxShadow: AppShadows.floating,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.lgAll,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm + 2,
                AppSpacing.xs,
                AppSpacing.sm + 2,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.smAll,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      notification.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('in-app-notification-close'),
                    tooltip: 'Bildirimi kapat',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
