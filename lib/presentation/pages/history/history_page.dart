import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restore(Note note) async {
    try {
      await context.read<NoteProvider>().archiveNote(
        note.id,
        isArchived: false,
      );
      if (mounted) _showMessage('笔记已恢复');
    } catch (error, stackTrace) {
      debugPrint('Failed to restore trashed note: $error\n$stackTrace');
      if (mounted) _showMessage('恢复失败，请重试');
    }
  }

  Future<void> _deletePermanently(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除？'),
        content: Text('“${note.displayTitle}”删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmPermanentDeleteButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<NoteProvider>().deleteNote(note.id);
      if (mounted) _showMessage('笔记已永久删除');
    } catch (error, stackTrace) {
      debugPrint('Failed to permanently delete note: $error\n$stackTrace');
      if (mounted) _showMessage('删除失败，请重试');
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
        title: const Text('回收站'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
      ),
      body: Consumer<NoteProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = _query.trim().toLowerCase();
          final notes = provider.archivedNotes.where((note) {
            return query.isEmpty ||
                note.title.toLowerCase().contains(query) ||
                note.content.toLowerCase().contains(query) ||
                note.tags.any((tag) => tag.toLowerCase().contains(query));
          }).toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '这里的笔记不会出现在首页，可恢复或永久删除。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (provider.archivedNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: TextField(
                        key: const ValueKey('trashSearchField'),
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: '搜索回收站',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
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
                  Expanded(
                    child: notes.isEmpty
                        ? _TrashEmptyState(isSearching: query.isNotEmpty)
                        : RefreshIndicator(
                            onRefresh: provider.loadNotes,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 64),
                              itemCount: notes.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(indent: 58),
                              itemBuilder: (context, index) {
                                final note = notes[index];
                                return _TrashNoteTile(
                                  note: note,
                                  onRestore: () => _restore(note),
                                  onDelete: () => _deletePermanently(note),
                                );
                              },
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

class _TrashNoteTile extends StatelessWidget {
  const _TrashNoteTile({
    required this.note,
    required this.onRestore,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Text(
                  note.createdAt.day.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${note.createdAt.month}月',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                NoteInlinePreview(
                  note: note,
                  emptyText: '无正文内容',
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateUtil.formatDateTime(note.updatedAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (note.coverImage case final cover?) ...[
            const SizedBox(width: 8),
            NoteThumbnail(image: cover, size: 56),
          ],
          IconButton(
            key: ValueKey('restoreTrash-${note.id}'),
            onPressed: onRestore,
            icon: const Icon(Icons.restore_from_trash_outlined),
            tooltip: '恢复笔记',
          ),
          IconButton(
            key: ValueKey('deleteTrash-${note.id}'),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: '永久删除',
          ),
        ],
      ),
    );
  }
}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState({required this.isSearching});

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
              isSearching ? Icons.search_off : Icons.delete_sweep_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(isSearching ? '没有匹配的笔记' : '回收站是空的'),
          ],
        ),
      ),
    );
  }
}
