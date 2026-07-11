import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../routers/app_router.dart';

enum _HistoryFilter { all, active, archived }

const String _untaggedFilter = '__untagged__';

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

  void _openRandomReview() {
    final notes = context.read<NoteProvider>().activeNotes;
    if (notes.isEmpty) {
      _showMessage('还没有可回顾的笔记');
      return;
    }
    final note = notes[math.Random().nextInt(notes.length)];
    context.push('${AppRouter.editor}?noteId=${Uri.encodeComponent(note.id)}');
  }

  Future<void> _showTagSideSheet(
    List<String> tags,
    Map<String, int> counts,
    int totalCount,
    int untaggedCount,
    String? selectedTag,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭标签侧边栏',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final width = math.min(
          300.0,
          MediaQuery.sizeOf(dialogContext).width * 0.82,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Theme.of(dialogContext).colorScheme.surface,
            child: SafeArea(
              child: SizedBox(
                width: width,
                child: _TagSidebar(
                  tags: tags,
                  counts: counts,
                  totalCount: totalCount,
                  untaggedCount: untaggedCount,
                  selectedTag: selectedTag,
                  showClose: true,
                  onClose: () => Navigator.of(dialogContext).pop(),
                  onSelected: (tag) {
                    Navigator.of(dialogContext).pop();
                    setState(() => _selectedTag = tag);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
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
            key: const ValueKey('randomReviewButton'),
            icon: const Icon(Icons.shuffle_outlined),
            onPressed: _openRandomReview,
            tooltip: '随机回顾',
          ),
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
            for (final tag in Note.expandTagHierarchy(note.tags)) {
              tagCounts.update(tag, (count) => count + 1, ifAbsent: () => 1);
            }
          }
          final sortedTags = tagCounts.keys.toList()
            ..sort((first, second) => first.compareTo(second));
          final untaggedCount = statusFilteredNotes
              .where((note) => note.tags.isEmpty)
              .length;
          final selectedTagAvailable =
              _selectedTag == null ||
              (_selectedTag == _untaggedFilter
                  ? untaggedCount > 0
                  : tagCounts.containsKey(_selectedTag));
          final effectiveSelectedTag = selectedTagAvailable
              ? _selectedTag
              : null;
          if (!selectedTagAvailable) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedTag != null) {
                setState(() => _selectedTag = null);
              }
            });
          }
          final notes = effectiveSelectedTag == null
              ? statusFilteredNotes
              : effectiveSelectedTag == _untaggedFilter
              ? statusFilteredNotes.where((note) => note.tags.isEmpty).toList()
              : statusFilteredNotes
                    .where(
                      (note) =>
                          Note.matchesTag(note.tags, effectiveSelectedTag),
                    )
                    .toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
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
                  const SizedBox(height: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final results = _HistoryResults(
                          notes: notes,
                          isSearching:
                              _query.trim().isNotEmpty ||
                              effectiveSelectedTag != null,
                          onRefresh: noteProvider.loadNotes,
                          onArchive: _archiveNote,
                          onDelete: _deleteNote,
                          onTagSelected: (tag) {
                            setState(() => _selectedTag = tag);
                          },
                        );
                        if (constraints.maxWidth >= 720) {
                          return Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: _TagSidebar(
                                  tags: sortedTags,
                                  counts: tagCounts,
                                  totalCount: statusFilteredNotes.length,
                                  untaggedCount: untaggedCount,
                                  selectedTag: effectiveSelectedTag,
                                  onSelected: (tag) {
                                    setState(() => _selectedTag = tag);
                                  },
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(child: results),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                              child: Row(
                                children: [
                                  OutlinedButton.icon(
                                    key: const ValueKey(
                                      'historyTagSidebarButton',
                                    ),
                                    onPressed: () => _showTagSideSheet(
                                      sortedTags,
                                      tagCounts,
                                      statusFilteredNotes.length,
                                      untaggedCount,
                                      effectiveSelectedTag,
                                    ),
                                    icon: const Icon(Icons.tag_outlined),
                                    label: Text(
                                      effectiveSelectedTag == _untaggedFilter
                                          ? '无标签'
                                          : effectiveSelectedTag ?? '标签',
                                    ),
                                  ),
                                  if (effectiveSelectedTag != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () {
                                        setState(() => _selectedTag = null);
                                      },
                                      icon: const Icon(Icons.close),
                                      tooltip: '清除标签筛选',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(child: results),
                          ],
                        );
                      },
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

class _TagSidebar extends StatelessWidget {
  const _TagSidebar({
    required this.tags,
    required this.counts,
    required this.totalCount,
    required this.untaggedCount,
    required this.selectedTag,
    required this.onSelected,
    this.showClose = false,
    this.onClose,
  });

  final List<String> tags;
  final Map<String, int> counts;
  final int totalCount;
  final int untaggedCount;
  final String? selectedTag;
  final ValueChanged<String?> onSelected;
  final bool showClose;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '标签',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (showClose)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
            ],
          ),
          const SizedBox(height: 8),
          _TagSidebarTile(
            key: const ValueKey('historyTag-all'),
            label: '全部标签',
            count: totalCount,
            selected: selectedTag == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(height: 4),
          if (untaggedCount > 0) ...[
            _TagSidebarTile(
              key: const ValueKey('historyTag-untagged'),
              label: '无标签',
              count: untaggedCount,
              selected: selectedTag == _untaggedFilter,
              onTap: () => onSelected(_untaggedFilter),
            ),
            const SizedBox(height: 4),
          ],
          for (final tag in tags)
            _TagSidebarTile(
              key: ValueKey('historyTag-$tag'),
              label: tag,
              count: counts[tag] ?? 0,
              depth: tag.substring(1).split('/').length - 1,
              selected: selectedTag == tag,
              onTap: () => onSelected(tag),
            ),
          if (tags.isEmpty && untaggedCount == 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('暂无标签', style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _TagSidebarTile extends StatelessWidget {
  const _TagSidebarTile({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.depth = 0,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayLabel = depth == 0 ? label : label.split('/').last;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 38,
          padding: EdgeInsets.only(left: 10 + depth * 16, right: 10),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (depth > 0) ...[
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryResults extends StatelessWidget {
  const _HistoryResults({
    required this.notes,
    required this.isSearching,
    required this.onRefresh,
    required this.onArchive,
    required this.onDelete,
    required this.onTagSelected,
  });

  final List<Note> notes;
  final bool isSearching;
  final Future<void> Function() onRefresh;
  final ValueChanged<Note> onArchive;
  final ValueChanged<Note> onDelete;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return _HistoryEmptyState(isSearching: isSearching);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemBuilder: (context, index) {
          final note = notes[index];
          return _HistoryNoteCard(
            note: note,
            onArchive: () => onArchive(note),
            onDelete: () => onDelete(note),
            onTagSelected: onTagSelected,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemCount: notes.length,
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
