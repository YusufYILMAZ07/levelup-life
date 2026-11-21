import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_header.dart';
import 'steps/step_details.dart';
import 'steps/step_goals.dart';
import 'steps/step_identity.dart';
import 'steps/step_summary.dart';

/// 4 adımlı tanışma ve hedef belirleme sihirbazı.
///
/// Uygulama asla hazır/mock bir profille açılmaz: `GameState.isOnboarded`
/// false olduğu sürece router bu ekranı gösterir. Son adımda
/// `GameController.completeOnboarding` çağrılır; profil ve ilk görevler
/// kullanıcının cevaplarından üretilir.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _stepCount = 4;

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fieldController = TextEditingController();

  UserSetup _draft = UserSetup.empty;
  int _step = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _fieldController.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _draft.hasIdentity,
    1 => _draft.hasDetails,
    2 => _draft.hasGoals,
    _ => true,
  };

  String? get _hint => switch (_step) {
    0 when !_draft.hasIdentity => 'Devam etmek için adını yaz.',
    1 when !_draft.hasDetails =>
      _draft.isProfessional
          ? 'Devam etmek için sektörünü seç veya yaz.'
          : 'Devam etmek için bölümünü/alanını seç veya yaz.',
    2 when !_draft.hasGoals => 'En az bir hedef seç.',
    _ => null,
  };

  void _applyName(String value) {
    setState(() => _draft = _draft.copyWith(displayName: value));
  }

  void _applyRole(LifeRole role) {
    setState(() {
      _draft = _draft.copyWith(
        role: role,
        gradeYear: role.isStudentRole && role != LifeRole.examPrep
            ? (_draft.gradeYear == 0 ? 1 : _draft.gradeYear)
            : 0,
      );
    });
    _fieldController.text = role.isProfessionalRole
        ? _draft.sector
        : _draft.studyField;
  }

  void _applyField(String value) {
    setState(() {
      _draft = _draft.isProfessional
          ? _draft.copyWith(sector: value)
          : _draft.copyWith(studyField: value);
    });
  }

  void _applyGrade(int grade) {
    setState(() => _draft = _draft.copyWith(gradeYear: grade));
  }

  void _applyWorkload(Workload workload) {
    setState(() => _draft = _draft.copyWith(workload: workload));
  }

  void _applyTempo(DailyTempo tempo) {
    setState(() => _draft = _draft.copyWith(tempo: tempo));
  }

  void _toggleGoal(GoalType goal) {
    setState(() => _draft = _draft.toggleGoal(goal));
  }

  void _next() {
    if (!_canContinue) return;
    FocusScope.of(context).unfocus();
    if (_step == _stepCount - 1) {
      ref.read(gameProvider.notifier).completeOnboarding(_draft);
      return;
    }
    setState(() => _step += 1);
    _pageController.animateToPage(
      _step,
      duration: AppMotion.base,
      curve: AppMotion.standard,
    );
  }

  void _back() {
    if (_step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _step -= 1);
    _pageController.animateToPage(
      _step,
      duration: AppMotion.base,
      curve: AppMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const Positioned(
            top: -140,
            right: -90,
            child: _AuraBlob(color: AppColors.primary, size: 340),
          ),
          const Positioned(
            top: 160,
            left: -130,
            child: _AuraBlob(color: AppColors.accentBlue, size: 280),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppConstants.maxContentWidth,
                ),
                child: Column(
                  children: <Widget>[
                    _Header(step: _step, stepCount: _stepCount),
                    _StepProgress(step: _step, stepCount: _stepCount),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: <Widget>[
                          StepIdentity(
                            setup: _draft,
                            nameController: _nameController,
                            onNameChanged: _applyName,
                            onRoleChanged: _applyRole,
                          ),
                          StepDetails(
                            setup: _draft,
                            fieldController: _fieldController,
                            onFieldChanged: _applyField,
                            onGradeChanged: _applyGrade,
                            onWorkloadChanged: _applyWorkload,
                          ),
                          StepGoals(setup: _draft, onToggle: _toggleGoal),
                          StepSummary(
                            setup: _draft,
                            onTempoChanged: _applyTempo,
                          ),
                        ],
                      ),
                    ),
                    _BottomBar(
                      step: _step,
                      stepCount: _stepCount,
                      canContinue: _canContinue,
                      hint: _hint,
                      onBack: _back,
                      onNext: _next,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.stepCount});

  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.glow(
                AppColors.primary,
                opacity: 0.28,
                blur: 14,
                offset: const Offset(0, 6),
              ),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.textOnAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppConstants.appName,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  AppConstants.appTagline,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          InfoPill(
            label: '${step + 1} / $stepCount',
            color: AppColors.primary,
            background: AppColors.primary.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.stepCount});

  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < stepCount; index++) ...<Widget>[
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.standard,
                height: 6,
                decoration: BoxDecoration(
                  gradient: index <= step ? AppGradients.primary : null,
                  color: index <= step ? null : AppColors.surfaceSunken,
                  borderRadius: AppRadii.pillAll,
                ),
              ),
            ),
            if (index != stepCount - 1) const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.stepCount,
    required this.canContinue,
    required this.hint,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final int stepCount;
  final bool canContinue;
  final String? hint;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bool last = step == stepCount - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.md,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hint != null) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    hint!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: <Widget>[
              if (step > 0) ...<Widget>[
                Expanded(
                  child: SoftButton(
                    label: 'Geri',
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: last ? 'Maceraya Başla!' : 'Devam Et',
                  icon: last
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: canContinue ? onNext : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuraBlob extends StatelessWidget {
  const _AuraBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
