import 'package:flutter/material.dart';

import 'settings_page_scaffold.dart';
import 'settings_sections.dart';

/// Yerel yedekleme, geri yükleme ve sıfırlama.
class BackupDataPage extends StatelessWidget {
  const BackupDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPageScaffold(
      pageKey: Key('backup-data-page'),
      backKey: Key('backup-back'),
      title: 'Yedek & Veri',
      subtitle: 'Cihaz değişse de hikâyen kaybolmasın.',
      children: <Widget>[BackupSection()],
    );
  }
}
