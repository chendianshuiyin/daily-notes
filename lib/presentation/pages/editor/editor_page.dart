import 'package:flutter/material.dart';

/// 编辑页面
///
/// 笔记编辑器页面，支持富文本编辑
class EditorPage extends StatelessWidget {
  const EditorPage({super.key, this.noteId});

  /// 要编辑的笔记 ID，如果为 null 则创建新笔记
  final String? noteId;

  @override
  Widget build(BuildContext context) {
    final isNewNote = noteId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewNote ? '新建笔记' : '编辑笔记'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // TODO: 保存笔记
            },
            tooltip: '保存',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              // TODO: 处理菜单选项
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'archive', child: Text('归档')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('编辑器占位', style: TextStyle(fontSize: 24, color: Colors.grey)),
            SizedBox(height: 8),
            Text(
              '这里将显示富文本编辑器',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
