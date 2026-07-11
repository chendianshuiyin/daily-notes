import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_color_palette.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/services/services.dart';
import '../../providers/providers.dart';

/// Application settings and local data management.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _portability = NotePortabilityService();

  Future<void> _checkForUpdates(BuildContext context) async {
    final updates = context.read<AppUpdateProvider>();
    final release = await updates.checkForUpdates();
    if (!context.mounted) return;
    if (release == null) {
      _showMessage(
        context,
        updates.errorMessage ?? '当前已是最新版本 v${updates.currentVersion}',
      );
      return;
    }
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppUpdateDialog(
        currentVersion: updates.currentVersion,
        release: release,
      ),
    );
    if (shouldOpen == true && context.mounted) {
      final opened = await updates.openAvailableUpdate();
      if (!opened && context.mounted) {
        _showMessage(context, '无法打开更新下载地址');
      }
    }
  }

  Future<void> _exportNotes(BuildContext context) async {
    final format = await showModalBottomSheet<NoteExportFormat>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '选择导出格式',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                  ),
                ],
              ),
              ListTile(
                key: const ValueKey('exportMarkdownZipOption'),
                leading: const Icon(Icons.folder_zip_outlined),
                title: const Text('Markdown ZIP'),
                subtitle: const Text('跨应用迁移，包含 Markdown 与图片目录'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(NoteExportFormat.markdownZip),
              ),
              ListTile(
                key: const ValueKey('exportJsonOption'),
                leading: const Icon(Icons.data_object),
                title: const Text('Daily Notes JSON'),
                subtitle: const Text('无损备份，保留内容块、图片和完整元数据'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(NoteExportFormat.dailyNotesJson),
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null || !context.mounted) {
      return;
    }
    final noteProvider = context.read<NoteProvider>();
    if (noteProvider.notes.isEmpty) {
      _showMessage(context, '还没有可导出的笔记');
      return;
    }
    try {
      _showMessage(context, '正在准备 ${noteProvider.notes.length} 条笔记…');
      final bytes = await _portability.export(noteProvider.notes, format);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final date = DateTime.now();
      final stamp =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final isMarkdown = format == NoteExportFormat.markdownZip;
      final fileName = isMarkdown
          ? 'daily-notes-$stamp-markdown.zip'
          : 'daily-notes-$stamp-backup.json';
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出笔记',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [isMarkdown ? 'zip' : 'json'],
        bytes: bytes,
        lockParentWindow: true,
      );
      if (!context.mounted || (!kIsWeb && savedPath == null)) return;
      _showMessage(context, '已导出 ${noteProvider.notes.length} 条笔记');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '导出失败，请重试或减少单次导出内容');
      }
    }
  }

  Future<void> _importNotes(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入笔记',
        type: FileType.custom,
        allowedExtensions: ['zip', 'md', 'markdown', 'json'],
        allowMultiple: false,
        withData: true,
        lockParentWindow: true,
      );
      if (result == null || !context.mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _showMessage(context, '无法读取所选文件');
        return;
      }
      _showMessage(context, '正在检查 ${file.name}…');
      final bundle = await _portability.inspectImport(file.name, bytes);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final noteProvider = context.read<NoteProvider>();
      if (bundle.notes.isEmpty) {
        _showMessage(context, '文件中没有可导入的笔记');
        return;
      }
      final imageCount = bundle.notes.fold<int>(
        0,
        (total, note) => total + note.images.length,
      );
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('confirmFileImportDialog'),
          title: const Text('导入这些笔记？'),
          content: Text(
            '${bundle.formatLabel} 中包含 ${bundle.notes.length} 条笔记'
            '${imageCount == 0 ? '' : '、$imageCount 张图片'}。同 ID 笔记将以导入内容覆盖，其他笔记保留。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirmFileImportButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );

      if (shouldRestore != true || !context.mounted) {
        return;
      }

      await noteProvider.restoreBackup(
        NoteBackup(exportedAt: DateTime.now(), notes: bundle.notes),
      );
      if (context.mounted) {
        _showMessage(context, '已导入 ${bundle.notes.length} 条笔记');
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message.toString());
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '导入失败，请检查文件后重试');
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

  Future<void> _showAiConfigDialog(BuildContext context) async {
    final provider = context.read<AiProvider>();
    final current = provider.config;
    final endpointController = TextEditingController(
      text: current?.endpoint ?? 'https://api.openai.com/v1',
    );
    final modelController = TextEditingController(text: current?.model ?? '');
    final keyController = TextEditingController(text: current?.apiKey ?? '');
    var obscureKey = true;
    String? errorMessage;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('AI 配置'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const ValueKey('aiEndpointField'),
                      controller: endpointController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'OpenAI-compatible API 地址',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('aiModelField'),
                      controller: modelController,
                      decoration: const InputDecoration(
                        labelText: '模型名称',
                        hintText: '例如 gpt-4.1-mini',
                        prefixIcon: Icon(Icons.memory_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('aiApiKeyField'),
                      controller: keyController,
                      obscureText: obscureKey,
                      decoration: InputDecoration(
                        labelText: 'API key（本地服务可留空）',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setDialogState(() => obscureKey = !obscureKey),
                          icon: Icon(
                            obscureKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: obscureKey ? '显示 API key' : '隐藏 API key',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('仅在你确认远端操作后发送所选笔记文字；图片和 WebDAV 凭据不会发送。'),
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
                  key: const ValueKey('clearAiConfigButton'),
                  onPressed: provider.isBusy
                      ? null
                      : () async {
                          await provider.clear();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: const Text('删除配置'),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('saveAiConfigButton'),
                onPressed: provider.isBusy
                    ? null
                    : () async {
                        try {
                          final config = AiConfig.validated(
                            endpoint: endpointController.text,
                            model: modelController.text,
                            apiKey: keyController.text,
                          );
                          await provider.save(config);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } on FormatException catch (error) {
                          setDialogState(
                            () => errorMessage = error.message.toString(),
                          );
                        } catch (_) {
                          setDialogState(() => errorMessage = 'AI 配置保存失败');
                        }
                      },
                child: const Text('保存配置'),
              ),
            ],
          ),
        ),
      );
    } finally {
      endpointController.dispose();
      modelController.dispose();
      keyController.dispose();
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
          final ai = context.watch<AiProvider>();
          final updates = context.watch<AppUpdateProvider>();
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
                    children: [
                      _ColorPaletteItem(settings: settings),
                      _ThemeModeItem(settings: settings),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '数据管理',
                    children: [
                      _SettingsItem(
                        key: const ValueKey('exportNotesItem'),
                        icon: Icons.ios_share_outlined,
                        title: '导出笔记',
                        subtitle: 'Markdown ZIP / JSON 文件',
                        onTap: () => _exportNotes(context),
                      ),
                      _SettingsItem(
                        key: const ValueKey('importNotesItem'),
                        icon: Icons.file_open_outlined,
                        title: '导入笔记',
                        subtitle: '支持 ZIP、Markdown 与 JSON',
                        onTap: () => _importNotes(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'AI 辅助',
                    children: [
                      _SettingsItem(
                        key: const ValueKey('aiConfigItem'),
                        icon: Icons.memory_outlined,
                        title: '远端模型配置',
                        subtitle: ai.isConfigured
                            ? '${ai.config!.model} · 已加密保存'
                            : '未配置，本地智能标签仍可使用',
                        onTap: ai.isBusy
                            ? null
                            : () => _showAiConfigDialog(context),
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
                  _SettingsSection(
                    title: '更新',
                    children: [
                      _AutoUpdateItem(updates: updates),
                      _SettingsItem(
                        key: const ValueKey('checkAppUpdateItem'),
                        icon: Icons.system_update_outlined,
                        title: '检查更新',
                        subtitle: updates.availableRelease != null
                            ? '发现 v${updates.availableRelease!.version}'
                            : updates.errorMessage ??
                                  '当前版本 v${updates.currentVersion}',
                        trailing: updates.isChecking
                            ? const _SettingsProgress()
                            : null,
                        onTap: updates.isChecking
                            ? null
                            : () => _checkForUpdates(context),
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
                        subtitle: '1.2.0',
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lock_outline, color: colors.primary),
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
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const Divider(indent: 56),
            ],
          ],
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
      contentPadding: EdgeInsets.zero,
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
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('明暗模式'),
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
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPaletteItem extends StatelessWidget {
  const _ColorPaletteItem({required this.settings});

  final AppSettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.color_lens_outlined),
      title: const Text('配色'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SegmentedButton<AppColorPalette>(
          key: const ValueKey('colorPaletteSegmentedButton'),
          showSelectedIcon: false,
          segments: [
            for (final palette in AppColorPalette.values)
              ButtonSegment(
                value: palette,
                label: Text(palette.shortLabel),
                tooltip: palette.label,
              ),
          ],
          selected: {settings.colorPalette},
          onSelectionChanged: (selection) {
            settings.setColorPalette(selection.first);
          },
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoUpdateItem extends StatelessWidget {
  const _AutoUpdateItem({required this.updates});

  final AppUpdateProvider updates;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const ValueKey('autoUpdateSwitch'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.update_outlined),
      title: const Text('自动检查更新'),
      subtitle: const Text('每 24 小时检查一次，不会自动安装'),
      value: updates.autoCheck,
      onChanged: updates.setAutoCheck,
    );
  }
}
