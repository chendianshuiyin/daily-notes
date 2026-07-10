import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/services/services.dart';
import '../../providers/providers.dart';

/// Application settings and local data management.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _copyBackup(BuildContext context) async {
    final noteProvider = context.read<NoteProvider>();
    try {
      await Clipboard.setData(ClipboardData(text: noteProvider.createBackup()));
      if (!context.mounted) {
        return;
      }
      _showMessage(context, '已复制 ${noteProvider.notes.length} 条笔记的 JSON 备份');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '复制备份失败，请重试');
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (!context.mounted) {
        return;
      }

      final source = clipboardData?.text?.trim() ?? '';
      if (source.isEmpty) {
        _showMessage(context, '剪贴板中没有可导入的备份');
        return;
      }

      final noteProvider = context.read<NoteProvider>();
      final backup = noteProvider.inspectBackup(source);
      if (backup.notes.isEmpty) {
        _showMessage(context, '备份中没有笔记');
        return;
      }

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('恢复笔记备份？'),
          content: Text(
            '将导入 ${backup.notes.length} 条笔记。现有同 ID 笔记会被备份内容覆盖，其他笔记会保留。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );

      if (shouldRestore != true || !context.mounted) {
        return;
      }

      await noteProvider.restoreBackup(backup);
      if (context.mounted) {
        _showMessage(context, '已恢复 ${backup.notes.length} 条笔记');
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message.toString());
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '恢复备份失败，请检查内容后重试');
      }
    }
  }

  Future<void> _showWebDavDialog(BuildContext context) async {
    final provider = context.read<WebDavProvider>();
    final current = provider.config;
    final serverController = TextEditingController(
      text: current?.serverUrl ?? '',
    );
    final usernameController = TextEditingController(
      text: current?.username ?? '',
    );
    final passwordController = TextEditingController(
      text: current?.password ?? '',
    );
    final directoryController = TextEditingController(
      text: current?.remoteDirectory ?? '/DailyNotes',
    );
    var obscurePassword = true;
    var isWorking = false;
    String? errorMessage;

    WebDavConfig readConfig() {
      return WebDavConfig.validated(
        serverUrl: serverController.text,
        username: usernameController.text,
        password: passwordController.text,
        remoteDirectory: directoryController.text,
      );
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> run(
              Future<void> Function(WebDavConfig config) action, {
              required bool closeWhenDone,
            }) async {
              setDialogState(() {
                isWorking = true;
                errorMessage = null;
              });
              try {
                await action(readConfig());
                if (!dialogContext.mounted) {
                  return;
                }
                if (closeWhenDone) {
                  Navigator.of(dialogContext).pop();
                } else {
                  setDialogState(() => isWorking = false);
                }
              } on FormatException catch (error) {
                setDialogState(() {
                  isWorking = false;
                  errorMessage = error.message.toString();
                });
              } on WebDavSyncException catch (error) {
                setDialogState(() {
                  isWorking = false;
                  errorMessage = error.message;
                });
              } catch (_) {
                setDialogState(() {
                  isWorking = false;
                  errorMessage = 'WebDAV 操作失败';
                });
              }
            }

            return AlertDialog(
              title: const Text('WebDAV 同步'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        key: const ValueKey('webDavServerField'),
                        controller: serverController,
                        enabled: !isWorking,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: '服务器地址',
                          hintText: 'https://dav.example.com/',
                          prefixIcon: Icon(Icons.cloud_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('webDavUsernameField'),
                        controller: usernameController,
                        enabled: !isWorking,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('webDavPasswordField'),
                        controller: passwordController,
                        enabled: !isWorking,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: '密码或应用密码',
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            onPressed: isWorking
                                ? null
                                : () => setDialogState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: obscurePassword ? '显示密码' : '隐藏密码',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('webDavDirectoryField'),
                        controller: directoryController,
                        enabled: !isWorking,
                        decoration: const InputDecoration(
                          labelText: '远端目录',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (current != null)
                  TextButton(
                    onPressed: isWorking
                        ? null
                        : () async {
                            await provider.clearConfig();
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                    child: const Text('清除配置'),
                  ),
                TextButton(
                  onPressed: isWorking
                      ? null
                      : () =>
                            run(provider.testConnection, closeWhenDone: false),
                  child: const Text('测试连接'),
                ),
                FilledButton(
                  onPressed: isWorking
                      ? null
                      : () => run(provider.saveAndTest, closeWhenDone: true),
                  child: isWorking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存并测试'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      serverController.dispose();
      usernameController.dispose();
      passwordController.dispose();
      directoryController.dispose();
    }

    if (context.mounted && provider.message != null) {
      _showMessage(context, provider.message!);
    }
  }

  Future<void> _runWebDavAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      if (context.mounted) {
        final message = context.read<WebDavProvider>().message;
        _showMessage(context, message ?? 'WebDAV 操作完成');
      }
    } on WebDavSyncException catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'WebDAV 操作失败');
      }
    }
  }

  Future<void> _confirmUpload(BuildContext context) async {
    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('覆盖远端备份？'),
        content: const Text('将用当前设备的全部笔记替换远端备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('覆盖上传'),
          ),
        ],
      ),
    );
    if (shouldUpload != true || !context.mounted) {
      return;
    }
    final webDav = context.read<WebDavProvider>();
    final notes = context.read<NoteProvider>();
    await _runWebDavAction(context, () => webDav.upload(notes));
  }

  String _webDavStatus(WebDavProvider provider) {
    if (!provider.isConfigured) {
      return '未配置';
    }
    final lastSync = provider.lastSyncAt;
    if (lastSync == null) {
      return provider.config!.serverUrl;
    }
    final minute = lastSync.minute.toString().padLeft(2, '0');
    return '上次同步 ${lastSync.month}月${lastSync.day}日 ${lastSync.hour}:$minute';
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
      ),
      body: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
          final noteCount = context.watch<NoteProvider>().notes.length;
          final webDav = context.watch<WebDavProvider>();
          final noteProvider = context.read<NoteProvider>();
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 64),
                children: [
                  _SettingsIntro(noteCount: noteCount),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '外观',
                    children: [_ThemeModeItem(settings: settings)],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '数据管理',
                    children: [
                      _SettingsItem(
                        icon: Icons.copy_all_outlined,
                        title: '复制笔记备份',
                        subtitle: '将全部图文笔记复制为 JSON',
                        onTap: () => _copyBackup(context),
                      ),
                      _SettingsItem(
                        icon: Icons.settings_backup_restore_outlined,
                        title: '从剪贴板恢复',
                        subtitle: '合并备份，同 ID 内容将覆盖',
                        onTap: () => _restoreBackup(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '同步',
                    children: [
                      _SettingsItem(
                        key: const ValueKey('webDavConfigItem'),
                        icon: Icons.cloud_outlined,
                        title: 'WebDAV 配置',
                        subtitle: _webDavStatus(webDav),
                        onTap: webDav.isBusy
                            ? null
                            : () => _showWebDavDialog(context),
                      ),
                      _SettingsItem(
                        key: const ValueKey('webDavSyncItem'),
                        icon: Icons.sync,
                        title: '立即同步',
                        subtitle: '合并两端较新内容，不自动删除',
                        trailing: webDav.operation == WebDavOperation.syncing
                            ? const _SettingsProgress()
                            : null,
                        onTap: webDav.isConfigured && !webDav.isBusy
                            ? () => _runWebDavAction(
                                context,
                                () => webDav.synchronize(noteProvider),
                              )
                            : null,
                      ),
                      _SettingsItem(
                        key: const ValueKey('webDavUploadItem'),
                        icon: Icons.cloud_upload_outlined,
                        title: '覆盖上传',
                        subtitle: '用本地全量备份替换远端文件',
                        trailing: webDav.operation == WebDavOperation.uploading
                            ? const _SettingsProgress()
                            : null,
                        onTap: webDav.isConfigured && !webDav.isBusy
                            ? () => _confirmUpload(context)
                            : null,
                      ),
                      _SettingsItem(
                        key: const ValueKey('webDavDownloadItem'),
                        icon: Icons.cloud_download_outlined,
                        title: '下载并合并',
                        subtitle: '保留本地笔记，同 ID 以远端内容覆盖',
                        trailing:
                            webDav.operation == WebDavOperation.downloading
                            ? const _SettingsProgress()
                            : null,
                        onTap: webDav.isConfigured && !webDav.isBusy
                            ? () => _runWebDavAction(context, () async {
                                await webDav.download(noteProvider);
                              })
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SettingsSection(
                    title: '关于',
                    children: [
                      _SettingsItem(
                        icon: Icons.info_outlined,
                        title: '版本',
                        subtitle: '1.1.0',
                        showChevron: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({required this.noteCount});

  final int noteCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地优先', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '$noteCount 条笔记保存在此设备，可随时导出备份。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 设置项
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showChevron = true,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showChevron;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing:
          trailing ?? (showChevron ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}

class _SettingsProgress extends StatelessWidget {
  const _SettingsProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
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
