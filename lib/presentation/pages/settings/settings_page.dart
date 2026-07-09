import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

/// 设置页面
///
/// 应用设置，包括主题、WebDAV 同步配置等
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              _SettingsSection(
                title: '外观',
                children: [_ThemeModeItem(settings: settings)],
              ),
              const Divider(),
              const _SettingsSection(
                title: '同步',
                children: [
                  _SettingsItem(
                    icon: Icons.cloud_outlined,
                    title: 'WebDAV 同步',
                    subtitle: '未配置',
                    showChevron: false,
                  ),
                ],
              ),
              const Divider(),
              const _SettingsSection(
                title: '关于',
                children: [
                  _SettingsItem(
                    icon: Icons.info_outlined,
                    title: '版本',
                    subtitle: '1.0.1',
                    showChevron: false,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 设置分区
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// 设置项
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: showChevron ? const Icon(Icons.chevron_right) : null,
    );
  }
}

class _ThemeModeItem extends StatelessWidget {
  const _ThemeModeItem({required this.settings});

  final AppSettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('主题'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SegmentedButton<ThemeMode>(
          key: const ValueKey('themeModeSegmentedButton'),
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('系统'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('浅色'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('深色'),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (selection) {
            settings.setThemeMode(selection.first);
          },
        ),
      ),
    );
  }
}
