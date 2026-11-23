import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/pin_lock_controller.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../../services/app_settings.dart';
import '../../services/biometric_service.dart';
import '../../services/pin_security.dart';
import '../widgets/partner_avatar.dart';

/// Açılışta / uygulamaya dönüşte gösterilen zarif 4 haneli numpad kilidi.
///
/// PIN varsayılan olarak yıldönümümüz **3101**'dir; Ayarlar → Gizlilik
/// bölümünden değiştirilebilir. Kilit kapalıysa bu ekran hiç çizilmez.
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  static const int _pinLength = 4;

  String _entered = '';
  String? _error;
  bool _checking = false;

  void _onDigit(String digit) {
    if (_checking || _entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == _pinLength) _submit();
  }

  void _onDelete() {
    if (_entered.isEmpty || _checking) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _error = null;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(appSettingsProvider).biometricEnabled) {
        _tryBiometric();
      }
    });
  }

  Future<void> _tryBiometric() async {
    if (!ref.read(appSettingsProvider).biometricEnabled) return;
    final BiometricResult result = await ref
        .read(pinLockProvider.notifier)
        .unlockWithBiometrics();
    if (!mounted || result.isSuccess) return;
    final String? message = result.message;
    if (message != null) setState(() => _error = message);
  }

  Future<void> _submit() async {
    final PinLockController controller = ref.read(pinLockProvider.notifier);
    if (controller.isLockedOut) {
      setState(() {
        _checking = false;
        _entered = '';
        _error =
            'Çok fazla deneme · ${controller.lockoutRemaining.inSeconds} sn '
            'sonra tekrar dene';
      });
      return;
    }
    setState(() => _checking = true);
    final bool ok = controller.unlockWithPin(_entered);
    if (ok) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    final bool lockedOut = controller.isLockedOut;
    final int remaining =
        PinAttemptPolicy.freeAttempts - controller.failedAttempts;
    setState(() {
      _error = lockedOut
          ? 'Bekleme süresi · ${controller.lockoutRemaining.inSeconds} sn'
          : remaining > 0 && remaining <= 2
          ? 'PIN hatalı · $remaining deneme hakkı kaldı'
          : 'PIN hatalı · tekrar dene';
      _entered = '';
      _checking = false;
    });
  }

  void _showHint() {
    final AppSettings settings = ref.read(appSettingsProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            settings.hasPin
                ? 'PIN yalnızca tuzlanmış hash olarak bu telefonda saklanır 🔒'
                : 'İpucu: Yıldönümümüz · 3101 💍',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFDF2F8), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        PartnerAvatar(
                          partnerId: CouplePartner.yusufId,
                          size: 46,
                          showRing: true,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        PartnerAvatar(
                          partnerId: CouplePartner.ceydaId,
                          size: 46,
                          showRing: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Yusuf & Ceyda',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: CouplePalette.ceyda,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Özel Alan',
                          style: AppTypography.bodySmall.copyWith(
                            color: CouplePalette.ceyda,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sohbetimiz ve anılarımız yalnızca bize açık.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int i = 0; i < _pinLength; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: AnimatedContainer(
                              key: Key('pin-dot-$i'),
                              duration: AppMotion.fast,
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _entered.length
                                    ? CouplePalette.ceyda
                                    : AppColors.surface,
                                border: Border.all(
                                  color: i < _entered.length
                                      ? CouplePalette.ceyda
                                      : AppColors.borderStrong,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: AppMotion.fast,
                          child: _error == null
                              ? const SizedBox.shrink()
                              : Text(
                                  _error!,
                                  key: const Key('pin-error'),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    _Numpad(
                      onDigit: _onDigit,
                      onDelete: _onDelete,
                      enabled: !_checking,
                    ),
                    if (ref.watch(
                      appSettingsProvider.select(
                        (AppSettings settings) => settings.biometricEnabled,
                      ),
                    )) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        key: const Key('pin-biometric'),
                        onPressed: _checking ? null : _tryBiometric,
                        icon: const Icon(
                          Icons.fingerprint_rounded,
                          size: 20,
                          color: CouplePalette.ceyda,
                        ),
                        label: Text(
                          'Face ID / Parmak İzi',
                          style: AppTypography.caption.copyWith(
                            color: CouplePalette.ceyda,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      key: const Key('pin-hint'),
                      onPressed: _showHint,
                      child: Text(
                        'PIN’i hatırlamıyorum',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.onDigit,
    required this.onDelete,
    required this.enabled,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onDelete;
  final bool enabled;

  static const List<List<String>> _rows = <List<String>>[
    <String>['1', '2', '3'],
    <String>['4', '5', '6'],
    <String>['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final List<String> row in _rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              for (final String digit in row)
                _PinKey(
                  key: Key('pin-key-$digit'),
                  label: digit,
                  onTap: enabled ? () => onDigit(digit) : null,
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            const SizedBox(width: 68, height: 68),
            _PinKey(
              key: const Key('pin-key-0'),
              label: '0',
              onTap: enabled ? () => onDigit('0') : null,
            ),
            _PinKey(
              key: const Key('pin-delete'),
              icon: Icons.backspace_outlined,
              onTap: enabled ? onDelete : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.onTap, this.label, this.icon, super.key});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Icon(icon, color: AppColors.textSecondary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
