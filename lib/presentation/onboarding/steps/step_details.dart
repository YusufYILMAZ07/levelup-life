import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/choice_card.dart';
import '../../widgets/section_header.dart';
import '../widgets/grade_selector.dart';
import '../widgets/step_title.dart';

/// Adım 2 — role göre **dinamik** detaylar.
///
/// Öğrenci → bölüm + sınıf, çalışan → sektör + yoğunluk, sınav → alan.
class StepDetails extends StatelessWidget {
  const StepDetails({
    required this.setup,
    required this.fieldController,
    required this.onFieldChanged,
    required this.onGradeChanged,
    required this.onWorkloadChanged,
    super.key,
  });

  final UserSetup setup;
  final TextEditingController fieldController;
  final ValueChanged<String> onFieldChanged;
  final ValueChanged<int> onGradeChanged;
  final ValueChanged<Workload> onWorkloadChanged;

  String get _currentValue =>
      setup.isProfessional ? setup.sector : setup.studyField;

  List<String> get _options => switch (setup.role) {
        LifeRole.student => const <String>[
            'Bilgisayar Mühendisliği',
            'Tıp',
            'Hukuk',
            'İşletme',
            'Psikoloji',
            'Elektrik-Elektronik',
            'Mimarlık',
            'Makine Mühendisliği',
          ],
        LifeRole.highSchool => const <String>[
            'Sayısal',
            'Eşit Ağırlık',
            'Sözel',
            'Dil',
            'Meslek Lisesi',
          ],
        LifeRole.examPrep => const <String>[
            'YKS Sayısal',
            'YKS Eşit Ağırlık',
            'YKS Sözel',
            'YKS Dil',
            'KPSS',
            'ALES',
            'YDS / IELTS',
          ],
        _ => const <String>[
            'Yazılım & Teknoloji',
            'Finans',
            'Pazarlama',
            'Tasarım',
            'Sağlık',
            'Eğitim',
            'Hukuk',
            'Mühendislik',
            'Girişimcilik',
          ],
      };

  String get _question => switch (setup.role) {
        LifeRole.student => 'Bölümün ne?',
        LifeRole.highSchool => 'Alanın ne?',
        LifeRole.examPrep => 'Hangi alanda hazırlanıyorsun?',
        _ => 'Hangi sektördesin?',
      };

  String get _hint => switch (setup.role) {
        LifeRole.student => 'Örn. Bilgisayar Mühendisliği',
        LifeRole.highSchool => 'Örn. Sayısal',
        LifeRole.examPrep => 'Örn. YKS Sayısal',
        _ => 'Örn. Yazılım & Teknoloji',
      };

  @override
  Widget build(BuildContext context) {
    final String title = setup.isProfessional
        ? 'İşin ve tempon'
        : setup.role == LifeRole.examPrep
            ? 'Hedefin ve alanın'
            : 'Okulun ve bölümün';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        StepTitle(
          eyebrow: 'Detaylar',
          title: title,
          description: setup.role.tagline,
          icon: setup.role.icon,
        ),
        const SizedBox(height: AppSpacing.xxl),
        SectionHeader(
          title: _question,
          subtitle: 'Listeden seç veya kendin yaz.',
        ),
        SuggestionChips(
          options: _options,
          selected: _currentValue,
          color: setup.role.color,
          onSelect: (String value) {
            fieldController.text = value;
            onFieldChanged(value);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('onboarding-field-input'),
          controller: fieldController,
          onChanged: onFieldChanged,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: _hint,
            prefixIcon: Icon(
              setup.isProfessional
                  ? Icons.work_outline_rounded
                  : Icons.school_outlined,
            ),
          ),
        ),
        if (setup.isStudent && setup.role != LifeRole.examPrep) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            title: 'Kaçıncı sınıfsın?',
            subtitle: 'Görev zorluğu sınıf seviyene göre ayarlanır.',
          ),
          GradeSelector(
            value: setup.gradeYear,
            onChanged: onGradeChanged,
          ),
        ],
        if (setup.isProfessional) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            title: 'Günlük çalışma yoğunluğun nasıl?',
            subtitle: 'Yoğun günlerde görevler kısalır, seri korunur.',
          ),
          for (final Workload workload in Workload.values) ...<Widget>[
            ChoiceCard(
              key: ValueKey<String>('workload-${workload.code}'),
              title: workload.label,
              subtitle: workload.description,
              icon: switch (workload) {
                Workload.light => Icons.weekend_rounded,
                Workload.balanced => Icons.balance_rounded,
                Workload.intense => Icons.local_fire_department_rounded,
              },
              color: setup.role.color,
              selected: setup.workload == workload,
              onTap: () => onWorkloadChanged(workload),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}
