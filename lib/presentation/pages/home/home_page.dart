import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../routers/app_router.dart';

/// Home dashboard with activity history and recent notes.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_stories_outlined, size: 22),
            SizedBox(width: 10),
            Text('Daily Notes'),
          ],
        ),
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
          final selectedNotes = noteProvider.notesForDay(_selectedDate);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: RefreshIndicator(
                onRefresh: noteProvider.loadNotes,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                  children: [
                    const _DashboardHeader(),
                    const SizedBox(height: 16),
                    _SummaryRow(
                      todayCount: todayNotes.length,
                      totalCount: noteProvider.activeNotes.length,
                      streakCount: noteProvider.currentStreak,
                    ),
                    const SizedBox(height: 16),
                    NoteActivityHeatmap(
                      activityByDay: noteProvider.activityByDay,
                      selectedDate: _selectedDate,
                      onDateSelected: (date) {
                        setState(() => _selectedDate = _dateOnly(date));
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: '每日详情 · ${_formatDay(_selectedDate)}',
                      count: selectedNotes.length,
                    ),
                    const SizedBox(height: 10),
                    if (selectedNotes.isEmpty)
                      const _DayEmptyState()
                    else
                      ...selectedNotes.map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NoteCard(note: note),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _SectionHeader(title: '最近更新', count: recentNotes.length),
                    const SizedBox(height: 10),
                    if (recentNotes.isEmpty)
                      const _InlineEmptyState()
                    else
                      ...recentNotes.map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NoteCard(note: note),
                        ),
                      ),
                  ],
                ),
              ),
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

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _formatDay(DateTime value) {
    return '${value.month}月${value.day}日';
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('统计总览', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                '${now.year}年${now.month}月${now.day}日',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 15,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 5),
              const Text('本地保存'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.todayCount,
    required this.totalCount,
    required this.streakCount,
  });

  final int todayCount;
  final int totalCount;
  final int streakCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 3;
        return Row(
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.notes_outlined,
                label: '总记录',
                value: totalCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.today_outlined,
                label: '今日',
                value: todayCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.local_fire_department_outlined,
                label: '连续天数',
                value: streakCount.toString(),
              ),
            ),
          ],
        );
      },
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
      child: SizedBox(
        height: 112,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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
        leading: note.images.isNotEmpty
            ? NoteThumbnail(image: note.images.first)
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(
                  note.isArchived
                      ? Icons.archive_outlined
                      : Icons.description_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
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

class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            const Text('这一天还没有记录'),
          ],
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.edit_note_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('还没有笔记，点击右下角开始记录。')),
          ],
        ),
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
