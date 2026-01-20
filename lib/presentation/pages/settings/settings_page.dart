import 'package:flutter/material.dart';

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
      body: ListView(
        children: [
          // 外观设置
          const _SettingsSection(
            title: '外观',
            children: [
              _SettingsItem(
                icon: Icons.palette_outlined,
                title: '主题',
                subtitle: '跟随系统',
              ),
            ],
          ),
          const Divider(),
          // 同步设置
          const _SettingsSection(
            title: '同步',
            children: [
              _SettingsItem(
                icon: Icons.cloud_outlined,
                title: 'WebDAV 同步',
                subtitle: '未配置',
              ),
            ],
          ),
          const Divider(),
          // 关于
          const _SettingsSection(
            title: '关于',
            children: [
              _SettingsItem(
                icon: Icons.info_outlined,
                title: '版本',
                subtitle: '1.0.0',
              ),
            ],
          ),
        ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: 处理点击
      },
    );
  }
}
