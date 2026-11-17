import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../progress/progress_screen.dart';

/// Alt sekme kabuğu: **Bugün** (dashboard) ve **İlerleme** (geçmiş).
///
/// `IndexedStack` kullanılır: dashboard'un kaydırma konumu ve İlerleme
/// sekmesinin 7/30 gün seçimi sekmeler arasında korunur.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const List<_ShellTab> _tabs = <_ShellTab>[
    _ShellTab(
      label: 'Bugün',
      icon: Icons.today_outlined,
      activeIcon: Icons.today_rounded,
      navKey: Key('nav-today'),
    ),
    _ShellTab(
      label: 'İlerleme',
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      navKey: Key('nav-progress'),
    ),
  ];

  int _index = 0;

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          DashboardScreen(key: ValueKey<String>('dashboard')),
          ProgressScreen(key: ValueKey<String>('progress')),
        ],
      ),
      bottomNavigationBar: _ShellNavBar(
        tabs: _tabs,
        index: _index,
        onSelect: _select,
      ),
    );
  }
}

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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.card,
      ),
      child: SafeArea(
        top: false,
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
                      child: Align(
                        alignment: Alignment.center,
                        // `heightFactor: 1` → buton satırı içeriğe göre
                        // yükselir; aksi halde Align mevcut yüksekliğin
                        // tamamını kaplar ve Scaffold gövdesine yer kalmaz.
                        heightFactor: 1,
                        child: _NavButton(
                          tab: tabs[i],
                          selected: i == index,
                          onTap: () => onSelect(i),
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
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(selected ? tab.activeIcon : tab.icon, size: 21, color: color),
                const SizedBox(height: 3),
                Text(
                  tab.label,
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
