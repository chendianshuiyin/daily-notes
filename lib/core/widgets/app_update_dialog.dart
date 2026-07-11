import 'package:flutter/material.dart';

import '../../data/services/services.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.currentVersion,
    required this.release,
  });

  final String currentVersion;
  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final published = release.publishedAt?.toLocal();
    final date = published == null
        ? null
        : '${published.year}-${published.month.toString().padLeft(2, '0')}-${published.day.toString().padLeft(2, '0')}';
    final notes = release.notes.trim();
    return AlertDialog(
      key: const ValueKey('appUpdateDialog'),
      title: const Text('发现新版本'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v$currentVersion  →  v${release.version}'),
            if (date != null) ...[
              const SizedBox(height: 4),
              Text(date, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(
                    notes.length > 1200
                        ? '${notes.substring(0, 1200)}…'
                        : notes,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          key: const ValueKey('openAppUpdateButton'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.download_outlined),
          label: const Text('立即更新'),
        ),
      ],
    );
  }
}
