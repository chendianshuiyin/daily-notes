import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../routers/app_router.dart';

enum _HistoryFilter { all, active, archived }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _HistoryFilter _filter = _HistoryFilter.all;
  String? _selectedTag;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteNote(Note note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确认删除“${note.displayTitle}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await context.read<NoteProvider>().deleteNote(note.id);
      if (mounted) {
        _showMessage('笔记已删除');
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to delete note from history: $error\n$stackTrace');
      if (mounted) {
        _showMessage('删除失败，请重试');
      }
    }
  }

  Future<void> _archiveNote(Note note) async {
    try {
      await context.read<NoteProvider>().archiveNote(
        note.id,
        isArchived: !note.isArchived,
      );
      if (mounted) {
        _showMessage(note.isArchived ? '笔记已取消归档' : '笔记已归档');
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to archive note from history: $error\n$stackTrace');
      if (mounted) {
        _showMessage('归档操作失败，请重试');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<NoteProvider>().loadNotes(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final searchedNotes = noteProvider.searchNotes(_query);
          final statusFilteredNotes = searchedNotes.where((note) {
            return switch (_filter) {
              _HistoryFilter.all => true,
              _HistoryFilter.active => !note.isArchived,
              _HistoryFilter.archived => note.isArchived,
            };
          }).toList();
          final tagCounts = <String, int>{};
          for (final note in statusFilteredNotes) {
            for (final tag in note.tags) {
              tagCounts.update(tag, (count) => count + 1, ifAbsent: () => 1);
            }
          }
          final sortedTags = tagCounts.keys.toList()
            ..sort((first, second) => first.compareTo(second));
          final notes = _selectedTag == null
              ? statusFilteredNotes
              : statusFilteredNotes
                    .where((note) => note.tags.contains(_selectedTag))
                    .toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: TextField(
                      key: const ValueKey('historySearchField'),
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: '搜索标题、正文或 #标签',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close),
                                tooltip: '清除搜索',
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _FilterChip(
                          label: '全部',
                          count: searchedNotes.length,
                          selected: _filter == _HistoryFilter.all,
                          onSelected: () {
                            setState(() => _filter = _HistoryFilter.all);
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: '当前',
                          count: searchedNotes
                              .where((note) => !note.isArchived)
                              .length,
                          selected: _filter == _HistoryFilter.active,
                          onSelected: () {
                            setState(() => _filter = _HistoryFilter.active);
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: '已归档',
                          count: searchedNotes
                              .where((note) => note.isArchived)
                              .length,
                          selected: _filter == _HistoryFilter.archived,
                          onSelected: () {
                            setState(() => _filter = _HistoryFilter.archived);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TagArchiveBar(
                    tags: sortedTags,
                    counts: tagCounts,
                    selectedTag: _selectedTag,
                    onSelected: (tag) => setState(() => _selectedTag = tag),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: notes.isEmpty
                        ? _HistoryEmptyState(
                            isSearching:
                                _query.trim().isNotEmpty ||
                                _selectedTag != null,
                          )
                        : RefreshIndicator(
                            onRefresh: noteProvider.loadNotes,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemBuilder: (context, index) {
                                final note = notes[index];
                                return _HistoryNoteCard(
                                  note: note,
                                  onArchive: () => _archiveNote(note),
                                  onDelete: () => _deleteNote(note),
                                  onTagSelected: (tag) {
                                    setState(() => _selectedTag = tag);
                                  },
                                );
                              },
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemCount: notes.length,
                            ),
                          ),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Text('$label $count'),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: foreground),
      backgroundColor: colorScheme.surfaceContainerLow,
      selectedColor: colorScheme.primaryContainer,
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
      showCheckmark: false,
      avatar: selected ? Icon(Icons.check, size: 16, color: foreground) : null,
    );
  }
}

class _TagArchiveBar extends StatelessWidget {
  const _TagArchiveBar({
    required this.tags,
    required this.counts,
    required this.selectedTag,
    required this.onSelected,
  });

  final List<String> tags;
  final Map<String, int> counts;
  final String? selectedTag;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Icon(
            Icons.sell_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const ValueKey('historyTag-all'),
            label: const Text('全部标签'),
            selected: selectedTag == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final tag in tags) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: ValueKey('historyTag-$tag'),
              label: Text('$tag ${counts[tag]}'),
              selected: selectedTag == tag,
              onSelected: (_) => onSelected(tag),
            ),
          ],
          if (tags.isEmpty) ...[
            const SizedBox(width: 8),
            const Chip(label: Text('暂无 #标签')),
          ],
        ],
      ),
    );
  }
}

class _HistoryNoteCard extends StatelessWidget {
  const _HistoryNoteCard({
    required this.note,
    required this.onArchive,
    required this.onDelete,
    required this.onTagSelected,
  });

  final Note note;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
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
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBadge(date: note.createdAt),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (note.isArchived)
                          Tooltip(
                            message: '已归档',
                            child: Icon(
                              Icons.archive_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      note.preview.isEmpty ? '无正文内容' : note.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: note.tags
                                .take(3)
                                .map(
                                  (tag) => _TagLabel(
                                    tag: tag,
                                    onPressed: () => onTagSelected(tag),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        Text(
                          DateUtil.formatDateTime(note.updatedAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (note.images.isNotEmpty) ...[
                const SizedBox(width: 12),
                NoteThumbnail(image: note.images.first, size: 72),
              ],
              PopupMenuButton<String>(
                tooltip: '笔记操作',
                onSelected: (value) {
                  if (value == 'archive') {
                    onArchive();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(note.isArchived ? '取消归档' : '归档'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 62,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date.day.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('${date.month}月', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TagLabel extends StatelessWidget {
  const _TagLabel({required this.tag, required this.onPressed});

  final String tag;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(tag),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.history,
              size: 52,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(isSearching ? '没有匹配的笔记' : '还没有历史笔记'),
          ],
        ),
      ),
    );
  }
}
