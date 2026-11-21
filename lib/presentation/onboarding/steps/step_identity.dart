import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/choice_card.dart';
import '../../widgets/section_header.dart';
import '../widgets/step_title.dart';

/// Adım 1 — isim + hayat rolü.
class StepIdentity extends StatelessWidget {
  const StepIdentity({
    required this.setup,
    required this.nameController,
    required this.onNameChanged,
    required this.onRoleChanged,
    super.key,
  });

  final UserSetup setup;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<LifeRole> onRoleChanged;

  /// Sihirbazda sunulan dört rol (brief ile birebir).
  static const List<LifeRole> roles = <LifeRole>[
    LifeRole.student,
    LifeRole.highSchool,
    LifeRole.employee,
    LifeRole.examPrep,
  ];

  static String titleFor(LifeRole role) => switch (role) {
    LifeRole.student => 'Üniversite Öğrencisiyim',
    LifeRole.highSchool => 'Lise Öğrencisiyim',
    LifeRole.employee => 'Çalışıyorum / Profesyonelim',
    LifeRole.examPrep => 'Sınavlara Hazırlanıyorum',
    _ => role.label,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        const StepTitle(
          eyebrow: 'Tanışma',
          title: 'Sen kimsin?',
          description:
              'Sana adınla hitap edelim ve görevlerini hayatına göre şekillendirelim.',
          icon: Icons.waving_hand_rounded,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Adın / kullanıcı adın',
          style: AppTypography.subtitle.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('onboarding-name-field'),
          controller: nameController,
          onChanged: onNameChanged,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Örn. Yusuf',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'En az 2 karakter — karakter kartında bu isim görünecek.',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(
          title: 'Şu an hayatın hangi evresinde?',
          subtitle: 'Rolünü seç; görev havuzu buna göre ağırlıklanır.',
        ),
        for (final LifeRole role in roles) ...<Widget>[
          ChoiceCard(
            key: ValueKey<String>('role-${role.code}'),
            title: titleFor(role),
            subtitle: role.tagline,
            icon: role.icon,
            color: role.color,
            selected: setup.role == role,
            onTap: () => onRoleChanged(role),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
