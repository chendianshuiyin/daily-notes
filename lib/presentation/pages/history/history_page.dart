import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../routers/app_router.dart';

/// 历史页面
///
/// 显示历史笔记列表和搜索功能
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteNote(Note note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确认删除“${note.displayTitle}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await context.read<NoteProvider>().deleteNote(note.id);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('笔记已删除')));
  }

  Future<void> _archiveNote(Note note) async {
    await context.read<NoteProvider>().archiveNote(
      note.id,
      isArchived: !note.isArchived,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(note.isArchived ? '笔记已取消归档' : '笔记已归档')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索标题或正文',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('历史记录'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _query = '';
                  _searchController.clear();
                }
              });
            },
            tooltip: '搜索',
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

          final notes = noteProvider.searchNotes(_query);
          if (notes.isEmpty) {
            return _HistoryEmptyState(isSearching: _query.trim().isNotEmpty);
          }

          return RefreshIndicator(
            onRefresh: noteProvider.loadNotes,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final note = notes[index];
                return _HistoryNoteTile(
                  note: note,
                  onArchive: () => _archiveNote(note),
                  onDelete: () => _deleteNote(note),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: notes.length,
            ),
          );
        },
      ),
    );
  }
}

class _HistoryNoteTile extends StatelessWidget {
  const _HistoryNoteTile({
    required this.note,
    required this.onArchive,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          note.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            note.preview.isEmpty
                ? DateUtil.formatDateTime(note.updatedAt)
                : '${note.preview}\n${DateUtil.formatDateTime(note.updatedAt)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        leading: note.images.isEmpty
            ? Icon(
                note.isArchived
                    ? Icons.archive_outlined
                    : Icons.description_outlined,
              )
            : NoteThumbnail(image: note.images.first),
        trailing: PopupMenuButton<String>(
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
        onTap: () {
          context.push(
            '${AppRouter.editor}?noteId=${Uri.encodeComponent(note.id)}',
          );
        },
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
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(isSearching ? '没有匹配的笔记' : '还没有历史笔记'),
          ],
        ),
      ),
    );
  }
}
