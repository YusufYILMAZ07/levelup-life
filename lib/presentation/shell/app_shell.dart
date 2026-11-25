import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/shell_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../chat/chat_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../development/development_screen.dart';
import '../progress/progress_screen.dart';

/// Alt sekme kabuğu: **Bugün**, **Gelişim**, **Sohbet** ve **İlerleme**.
///
/// `IndexedStack` kullanılır: her sekmenin kaydırma konumu, İlerleme'deki
/// 7/30 gün seçimi ve sohbet taslağı sekmeler arasında korunur.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(shellTabProvider);
    return PopScope(
      canPop: index == ShellTabController.today,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || index == ShellTabController.today) return;
        ref.read(shellTabProvider.notifier).goTo(ShellTabController.today);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: index,
          children: const <Widget>[
            DashboardScreen(key: ValueKey<String>('dashboard')),
            DevelopmentScreen(key: ValueKey<String>('development')),
            ChatScreen(key: ValueKey<String>('chat')),
            ProgressScreen(key: ValueKey<String>('progress')),
          ],
        ),
        bottomNavigationBar: _ShellNavBar(
          tabs: _tabs,
          index: index,
          onSelect: ref.read(shellTabProvider.notifier).goTo,
        ),
      ),
    );
  }
}

/// Alt gezinme sekmeleri — ikon çifti seçili/seçili değil durumu için.
const List<_ShellTab> _tabs = <_ShellTab>[
  _ShellTab(
    label: 'Bugün',
    icon: Icons.today_outlined,
    activeIcon: Icons.today_rounded,
    navKey: Key('nav-today'),
  ),
  _ShellTab(
    label: 'Gelişim',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome_rounded,
    navKey: Key('nav-development'),
  ),
  _ShellTab(
    label: 'Sohbet',
    icon: Icons.chat_bubble_outline_rounded,
    activeIcon: Icons.chat_bubble_rounded,
    navKey: Key('nav-chat'),
  ),
  _ShellTab(
    label: 'İlerleme',
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights_rounded,
    navKey: Key('nav-progress'),
  ),
];

/// Sekme tanımı — ikon çifti seçili/seçili değil durumu için.
final class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.navKey,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Key navKey;
}

/// Beyaz, ince üst kenarlıklı alt gezinme çubuğu.
class _ShellNavBar extends StatelessWidget {
  const _ShellNavBar({
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final List<_ShellTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // iOS PWA'da SafeArea, Home Indicator alt insetini bazen 0 ölçer.
    // Web'de en az 16 pt bırakarak sekmelerin dokunma alanını koruruz.
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double safeBottom = kIsWeb
        ? math.max(bottomInset, 16.0)
        : bottomInset;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: safeBottom),
        child: Center(
          // `heightFactor: 1` şart: varsayılan Center kısıtlı yükseklikte
          // tüm gövdeyi kaplar ve Scaffold'a yer bırakmaz.
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < tabs.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTap: () => onSelect(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 54),
                          child: Center(
                            // Görsel pill dar kalır; tıklama alanı ise
                            // Expanded hücresinin tamamını kaplar.
                            heightFactor: 1,
                            child: _NavButton(
                              tab: tabs[i],
                              selected: i == index,
                              onTap: () => onSelect(i),
                            ),
                          ),
                        ),
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.primary : AppColors.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: AppRadii.pillAll,
        child: InkWell(
          key: tab.navKey,
          onTap: onTap,
          borderRadius: AppRadii.pillAll,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? tab.activeIcon : tab.icon,
                  size: 21,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
