import 'package:flutter/material.dart';

import 'settings_page_scaffold.dart';
import 'settings_sections.dart';

/// Uygulama kilidi ve PIN yönetimi.
class PrivacyPinPage extends StatelessWidget {
  const PrivacyPinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPageScaffold(
      pageKey: Key('privacy-pin-page'),
      backKey: Key('privacy-back'),
      title: 'Gizlilik & PIN',
      subtitle: 'Telefon el değiştirdiğinde anıların mahrem kalsın.',
      children: <Widget>[PrivacySection()],
    );
  }
}
