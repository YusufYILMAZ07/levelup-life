import 'package:flutter/material.dart';

import 'settings_page_scaffold.dart';
import 'settings_sections.dart';

/// Google Drive yedeği ve eşitleme durumu.
class CloudSyncPage extends StatelessWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPageScaffold(
      pageKey: Key('cloud-sync-page'),
      backKey: Key('cloud-sync-back'),
      title: 'Bulut & Eşitleme',
      subtitle: 'İkinizin ilerlemesi iki telefonda da aynı kalsın.',
      children: <Widget>[CloudSyncSection()],
    );
  }
}
