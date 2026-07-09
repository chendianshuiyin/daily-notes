import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../routers/app_router.dart';

/// 首页
///
/// 显示今日笔记列表和热力图
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRouter.history),
            tooltip: '历史记录',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRouter.settings),
            tooltip: '设置',
          ),
        ],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (noteProvider.errorMessage != null) {
            return _ErrorState(
              message: noteProvider.errorMessage!,
              onRetry: noteProvider.loadNotes,
            );
          }

          final todayNotes = noteProvider.todayNotes;
          final recentNotes = noteProvider.activeNotes.take(5).toList();

          return RefreshIndicator(
            onRefresh: noteProvider.loadNotes,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryRow(
                  todayCount: todayNotes.length,
                  totalCount: noteProvider.activeNotes.length,
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: '今日笔记', count: todayNotes.length),
                const SizedBox(height: 8),
                if (todayNotes.isEmpty)
                  const _EmptyState()
                else
                  ...todayNotes.map((note) => _NoteCard(note: note)),
                const SizedBox(height: 24),
                _SectionHeader(title: '最近更新', count: recentNotes.length),
                const SizedBox(height: 8),
                if (recentNotes.isEmpty)
                  const Text('还没有笔记，点击右下角开始记录。')
                else
                  ...recentNotes.map((note) => _NoteCard(note: note)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRouter.editor),
        tooltip: '新建笔记',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.todayCount, required this.totalCount});

  final int todayCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.today_outlined,
            label: '今日',
            value: todayCount.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.notes_outlined,
            label: '全部',
            value: totalCount.toString(),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Text('($count)', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          note.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          note.preview.isEmpty
              ? DateUtil.formatDateTime(note.updatedAt)
              : '${note.preview}\n${DateUtil.formatDateTime(note.updatedAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push(
            '${AppRouter.editor}?noteId=${Uri.encodeComponent(note.id)}',
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('今天还没有记录'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
