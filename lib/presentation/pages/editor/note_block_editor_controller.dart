import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';

import '../../../data/models/models.dart';

const noteImageIdAttribute = 'noteImageId';

class NoteBlockEditorController extends ChangeNotifier {
  NoteBlockEditorController({
    required List<NoteBlock> blocks,
    required List<NoteImage> images,
  }) : _images = List.of(images),
       editorState = EditorState(
         document: _documentFromBlocks(blocks, images),
       ) {
    editorState.selectionNotifier.addListener(_handleSelectionChanged);
    _subscription = editorState.transactionStream.listen((event) {
      if (event.$1 == TransactionTime.after) {
        notifyListeners();
        _scheduleHeadingNormalization();
      }
    });
  }

  final EditorState editorState;
  final List<NoteImage> _images;
  late final StreamSubscription<EditorTransactionValue> _subscription;
  Selection? _capturedSelection;
  bool _normalizingShortcut = false;
  bool _normalizationScheduled = false;
  bool _disposed = false;

  void _handleSelectionChanged() {
    notifyListeners();
  }

  void _scheduleHeadingNormalization() {
    if (_normalizationScheduled || _normalizingShortcut || _disposed) {
      return;
    }
    _normalizationScheduled = true;
    Future<void>.microtask(() async {
      _normalizationScheduled = false;
      if (!_disposed) {
        await _normalizeHeadingShortcut();
      }
    });
  }

  Future<bool> _normalizeHeadingShortcut() async {
    if (_normalizingShortcut) {
      return false;
    }
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      return false;
    }
    final node = editorState.document.nodeAtPath(selection.end.path);
    if (node == null || node.type != ParagraphBlockKeys.type) {
      return false;
    }
    final delta = node.delta;
    final text = delta?.toPlainText() ?? '';
    final match = RegExp(r'^(#{1,3})\s').firstMatch(text);
    if (match == null) {
      return false;
    }
    final prefixLength = match.group(0)!.length;
    final heading = headingNode(
      level: match.group(1)!.length,
      delta: delta!.slice(prefixLength),
    )..id = node.id;
    final path = node.path;
    final offset = (selection.end.offset - prefixLength).clamp(
      0,
      heading.delta?.length ?? 0,
    );
    _normalizingShortcut = true;
    try {
      final transaction = editorState.transaction
        ..deleteNode(node)
        ..insertNode(path, heading, deepCopy: false)
        ..afterSelection = Selection.collapsed(
          Position(path: path, offset: offset),
        );
      await editorState.apply(transaction);
      return true;
    } finally {
      _normalizingShortcut = false;
    }
  }

  List<NoteImage> get images => List.unmodifiable(_images);

  List<NoteBlock> get blocks {
    final result = <NoteBlock>[];
    for (final node in editorState.document.root.children) {
      _appendNode(result, node, 0);
    }
    return List.unmodifiable(result);
  }

  String get markdown => NoteDocument(blocks).toTextShadow();

  int get characterCount => blocks
      .where((block) => block.isText)
      .fold(0, (count, block) => count + block.text.trim().length);

  String? get selectedImageId {
    final path = editorState.selection?.end.path;
    if (path == null) {
      return null;
    }
    final node = editorState.document.nodeAtPath(path);
    return node?.type == ImageBlockKeys.type
        ? node?.attributes[noteImageIdAttribute] as String?
        : null;
  }

  Future<void> insertImages(List<NoteImage> selected) async {
    if (selected.isEmpty) {
      return;
    }
    _images.addAll(selected);
    final selectionPath = editorState.selection?.end.path;
    final rootIndex = selectionPath == null || selectionPath.isEmpty
        ? editorState.document.root.children.length
        : selectionPath.first + 1;
    final nodes = [...selected.map(_imageNode), paragraphNode()];
    final transaction = editorState.transaction
      ..insertNodes([rootIndex], nodes, deepCopy: false)
      ..afterSelection = Selection.collapsed(
        Position(path: [rootIndex + nodes.length - 1]),
      );
    await editorState.apply(transaction);
  }

  void captureInsertionSelection() {
    _capturedSelection = editorState.selection;
  }

  Future<void> insertText(
    String text, {
    bool atCapturedSelection = false,
  }) async {
    if (text.isEmpty) {
      return;
    }
    if (atCapturedSelection && _capturedSelection != null) {
      editorState.selection = _capturedSelection;
    }
    final selection = editorState.selection;
    if (selection != null && !selection.isCollapsed) {
      final start = selection.normalized.start;
      await editorState.deleteSelection(selection);
      editorState.selection = Selection.collapsed(start);
    }
    if (editorState.selection?.isCollapsed ?? false) {
      await editorState.insertTextAtCurrentSelection(text);
      _capturedSelection = null;
      return;
    }
    final last = editorState.document.last;
    if (last?.delta != null) {
      await editorState.insertText(last!.delta!.length, text, node: last);
      _capturedSelection = null;
      return;
    }
    final path = [editorState.document.root.children.length];
    final node = paragraphNode(text: text);
    await editorState.apply(editorState.transaction..insertNode(path, node));
    _capturedSelection = null;
  }

  Future<void> removeImage(String imageId) async {
    final node = _findImageNode(imageId);
    if (node == null) {
      return;
    }
    _images.removeWhere((image) => image.id == imageId);
    final transaction = editorState.transaction..deleteNode(node);
    if (editorState.document.root.children.length == 1) {
      transaction.insertNode([0], paragraphNode());
    }
    await editorState.apply(transaction);
  }

  Future<void> moveImage(String imageId, int direction) async {
    final node = _findImageNode(imageId);
    if (node == null || node.path.length != 1 || direction == 0) {
      return;
    }
    final index = node.path.first;
    final siblings = editorState.document.root.children;
    final targetIndex = (index + direction).clamp(0, siblings.length - 1);
    if (targetIndex == index) {
      return;
    }
    final target = siblings[targetIndex];
    final newPath = direction < 0 ? target.path : target.path.next;
    await editorState.apply(editorState.transaction..moveNode(newPath, node));
  }

  NoteImage? imageById(String imageId) {
    for (final image in _images) {
      if (image.id == imageId) {
        return image;
      }
    }
    return null;
  }

  Node? _findImageNode(String imageId) {
    for (final node in editorState.document.root.children) {
      if (node.type == ImageBlockKeys.type &&
          node.attributes[noteImageIdAttribute] == imageId) {
        return node;
      }
    }
    return null;
  }

  static Document _documentFromBlocks(
    List<NoteBlock> blocks,
    List<NoteImage> images,
  ) {
    final imageById = {for (final image in images) image.id: image};
    final nodes = <Node>[];
    for (final block in blocks) {
      if (block.type == NoteBlockType.image) {
        final image = imageById[block.imageId];
        if (image != null) {
          nodes.add(_imageNode(image, blockId: block.id));
        }
        continue;
      }
      nodes.addAll(_textNodes(block));
    }
    if (nodes.isEmpty || nodes.last.delta == null) {
      nodes.add(paragraphNode());
    }
    return Document(root: pageNode(children: nodes));
  }

  static List<Node> _textNodes(NoteBlock block) {
    if (block.type == NoteBlockType.divider) {
      return [dividerNode()..id = block.id];
    }
    final markdown = NoteDocument([block]).toTextShadow();
    final parsed = markdownToDocument(markdown).root.children;
    final nodes = parsed.isEmpty ? [paragraphNode(text: block.text)] : parsed;
    for (var index = 0; index < nodes.length; index++) {
      nodes[index].id = index == 0 ? block.id : '${block.id}-$index';
    }
    return nodes;
  }

  static Node _imageNode(NoteImage image, {String? blockId}) {
    return Node(
      type: ImageBlockKeys.type,
      id: blockId ?? 'image-${image.id}',
      attributes: {
        ImageBlockKeys.url: image.base64Data,
        ImageBlockKeys.align: 'left',
        ImageBlockKeys.width: 360.0,
        noteImageIdAttribute: image.id,
      },
    );
  }

  static void _appendNode(List<NoteBlock> result, Node node, int indent) {
    final type = switch (node.type) {
      HeadingBlockKeys.type => NoteBlockType.heading,
      BulletedListBlockKeys.type => NoteBlockType.bulletList,
      NumberedListBlockKeys.type => NoteBlockType.numberList,
      QuoteBlockKeys.type => NoteBlockType.quote,
      DividerBlockKeys.type => NoteBlockType.divider,
      ImageBlockKeys.type => NoteBlockType.image,
      _ => NoteBlockType.paragraph,
    };
    final imageId = node.attributes[noteImageIdAttribute] as String?;
    if (type != NoteBlockType.image || imageId != null) {
      result.add(
        NoteBlock(
          id: node.id,
          type: type,
          text: node.delta == null
              ? ''
              : DeltaMarkdownEncoder().convert(node.delta!),
          imageId: imageId,
          level: node.attributes[HeadingBlockKeys.level] as int? ?? 0,
          indent: indent,
        ),
      );
    }
    for (final child in node.children) {
      _appendNode(result, child, indent + 1);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    editorState.selectionNotifier.removeListener(_handleSelectionChanged);
    _subscription.cancel();
    editorState.dispose();
    super.dispose();
  }
}
