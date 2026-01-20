import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('首页占位', style: TextStyle(fontSize: 24, color: Colors.grey)),
            SizedBox(height: 8),
            Text(
              '这里将显示今日笔记和活动热力图',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRouter.editor),
        tooltip: '新建笔记',
        child: const Icon(Icons.add),
      ),
    );
  }
}
