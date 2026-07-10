import 'dart:convert';
import 'dart:typed_data';

import 'package:daily_notes/data/models/models.dart';
import 'package:daily_notes/data/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = WebDavConfig.validated(
    serverUrl: 'https://dav.example.com/root',
    username: 'daily-notes',
    password: 'app-password',
    remoteDirectory: 'notes/backups',
  );

  test('normalizes and validates WebDAV configuration', () {
    expect(config.serverUrl, 'https://dav.example.com/root/');
    expect(config.remoteDirectory, '/notes/backups');
    expect(config.remoteFilePath, '/notes/backups/daily-notes-backup.json');
    expect(
      () => WebDavConfig.validated(
        serverUrl: 'ftp://dav.example.com',
        username: 'user',
        password: 'password',
      ),
      throwsFormatException,
    );
  });

  test('creates a remote backup when none exists', () async {
    final remote = _MemoryWebDavRemote();
    final service = WebDavSyncService(remoteFactory: (_) => remote);
    final local = [_note('local', 2, content: '#工作/计划')];

    final result = await service.synchronize(config, local);

    expect(result.remoteWasMissing, isTrue);
    expect(result.remoteChangesApplied, 0);
    expect(result.notes.single.tags, ['#工作/计划']);
    expect(remote.directories, contains('/notes/backups'));
    expect(remote.bytes, isNotNull);
  });

  test('merges each note by the newest updatedAt value', () async {
    final remote = _MemoryWebDavRemote();
    const backupService = NoteBackupService();
    remote.bytes = Uint8List.fromList(
      utf8.encode(
        backupService.encode([
          _note('remote-wins', 4, content: '远端新版'),
          _note('local-wins', 2, content: '远端旧版'),
          _note('remote-only', 3, content: '远端独有'),
        ]),
      ),
    );
    final service = WebDavSyncService(remoteFactory: (_) => remote);

    final result = await service.synchronize(config, [
      _note('remote-wins', 1, content: '本地旧版'),
      _note('local-wins', 5, content: '本地新版'),
      _note('local-only', 3, content: '本地独有'),
    ]);

    final byId = {for (final note in result.notes) note.id: note};
    expect(byId, hasLength(4));
    expect(byId['remote-wins']!.content, '远端新版');
    expect(byId['local-wins']!.content, '本地新版');
    expect(byId['remote-only']!.content, '远端独有');
    expect(byId['local-only']!.content, '本地独有');
    expect(result.remoteChangesApplied, 2);

    final written = backupService.decode(utf8.decode(remote.bytes!));
    expect(written.notes, hasLength(4));
  });

  test('does not overwrite remote data when its backup is malformed', () async {
    final remote = _MemoryWebDavRemote()
      ..bytes = Uint8List.fromList(utf8.encode('{not-json'));
    final service = WebDavSyncService(remoteFactory: (_) => remote);

    expect(
      () => service.synchronize(config, [_note('local', 1)]),
      throwsA(isA<WebDavSyncException>()),
    );
    expect(remote.writeCount, 0);
  });
}

Note _note(String id, int day, {String content = ''}) {
  final updatedAt = DateTime.utc(2026, 7, day);
  return Note(
    id: id,
    title: id,
    content: content,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: updatedAt,
  );
}

class _MemoryWebDavRemote implements WebDavRemote {
  Uint8List? bytes;
  int writeCount = 0;
  final directories = <String>[];

  @override
  Future<void> ensureDirectory(String path) async {
    directories.add(path);
  }

  @override
  Future<void> ping() async {}

  @override
  Future<List<int>?> readOrNull(String path) async => bytes;

  @override
  Future<void> writeAtomic(String path, Uint8List data) async {
    writeCount++;
    bytes = Uint8List.fromList(data);
  }
}
