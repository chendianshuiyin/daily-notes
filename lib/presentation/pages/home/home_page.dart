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
  String? _selectedTag;

  static const _untagged = '__untagged__';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Consumer<NoteProvider>(
        builder: (context, notes, child) {
          final activeNotes = notes.activeNotes;
          final counts = <String, int>{};
          for (final note in activeNotes) {
            for (final tag in Note.expandTagHierarchy(note.tags)) {
              counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
            }
          }
          final tags = counts.keys.toList()..sort();
          return _HomeTagDrawer(
            tags: tags,
            counts: counts,
            totalCount: activeNotes.length,
            untaggedCount: activeNotes
                .where((note) => note.tags.isEmpty)
                .length,
            selectedTag: _selectedTag,
            onSelected: (tag) {
              setState(() => _selectedTag = tag);
              Navigator.of(context).pop();
            },
          );
        },
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            key: const ValueKey('homeSidebarButton'),
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            tooltip: '打开标签侧边栏',
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.auto_stories_outlined, size: 22),
            SizedBox(width: 10),
            Text('Daily Notes'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_stream_outlined),
            onPressed: () => context.push(AppRouter.history),
            tooltip: '全部笔记',
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
          bool matchesSelection(Note note) {
            return _selectedTag == null ||
                (_selectedTag == _untagged
                    ? note.tags.isEmpty
                    : Note.matchesTag(note.tags, _selectedTag!));
          }

          final visibleNotes = noteProvider.activeNotes
              .where(matchesSelection)
              .toList();
          final selectedNotes = noteProvider
              .notesForDay(_selectedDate)
              .where((note) => !note.isArchived && matchesSelection(note))
              .toList();

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
                          child: _NoteCard(
                            note: note,
                            onTagSelected: (tag) {
                              setState(() => _selectedTag = tag);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _SectionHeader(
                      title: _selectedTag == _untagged
                          ? '无标签笔记'
                          : _selectedTag ?? '全部笔记',
                      count: visibleNotes.length,
                    ),
                    const SizedBox(height: 10),
                    if (visibleNotes.isEmpty)
                      const _InlineEmptyState()
                    else
                      ...visibleNotes.map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NoteCard(
                            note: note,
                            onTagSelected: (tag) {
                              setState(() => _selectedTag = tag);
                            },
                          ),
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
  const _NoteCard({required this.note, required this.onTagSelected});

  final Note note;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          context.push(
            '${AppRouter.editor}?noteId=${Uri.encodeComponent(note.id)}',
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.title.trim().isNotEmpty) ...[
                      Text(
                        note.title.trim(),
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (note.bodyPreview.isNotEmpty)
                      Text(
                        note.bodyPreview,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: note.tags
                            .map(
                              (tag) => _InlineTag(
                                tag: tag,
                                onTap: () => onTagSelected(tag),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Text(
                      DateUtil.formatDateTime(note.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (note.images.isNotEmpty) ...[
                const SizedBox(width: 12),
                NoteThumbnail(image: note.images.first, size: 72),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  const _InlineTag({required this.tag, required this.onTap});

  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        tag,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HomeTagDrawer extends StatelessWidget {
  const _HomeTagDrawer({
    required this.tags,
    required this.counts,
    required this.totalCount,
    required this.untaggedCount,
    required this.selectedTag,
    required this.onSelected,
  });

  final List<String> tags;
  final Map<String, int> counts;
  final int totalCount;
  final int untaggedCount;
  final String? selectedTag;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '我的笔记',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭侧边栏',
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                children: [
                  _DrawerTagTile(
                    key: const ValueKey('homeTag-all'),
                    label: '全部笔记',
                    count: totalCount,
                    selected: selectedTag == null,
                    icon: Icons.view_stream_outlined,
                    onTap: () => onSelected(null),
                  ),
                  if (untaggedCount > 0)
                    _DrawerTagTile(
                      key: const ValueKey('homeTag-untagged'),
                      label: '无标签',
                      count: untaggedCount,
                      selected: selectedTag == _HomePageState._untagged,
                      icon: Icons.label_off_outlined,
                      onTap: () => onSelected(_HomePageState._untagged),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
                    child: Text(
                      '标签',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final tag in tags)
                    _DrawerTagTile(
                      key: ValueKey('homeTag-$tag'),
                      label: tag.substring(1).split('/').last,
                      count: counts[tag] ?? 0,
                      selected: selectedTag == tag,
                      depth: tag.substring(1).split('/').length - 1,
                      icon: Icons.tag,
                      onTap: () => onSelected(tag),
                    ),
                  if (tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '正文中的 #标签 会显示在这里',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTagTile extends StatelessWidget {
  const _DrawerTagTile({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.depth = 0,
  });

  final String label;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      minTileHeight: 40,
      contentPadding: EdgeInsets.only(left: 12 + depth * 18, right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      selected: selected,
      selectedTileColor: colors.primaryContainer,
      leading: Icon(icon, size: 18),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(count.toString()),
      onTap: onTap,
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
