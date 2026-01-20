import 'package:uuid/uuid.dart';

/// GUID 工具类
class GuidUtil {
  GuidUtil._();

  static const Uuid _uuid = Uuid();

  /// 生成 UUID v4
  static String generate() {
    return _uuid.v4();
  }

  /// 生成简短的 UUID (去掉横线)
  static String generateShort() {
    return _uuid.v4().replaceAll('-', '');
  }

  /// 验证字符串是否是有效的 UUID
  static bool isValid(String uuid) {
    final regex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return regex.hasMatch(uuid);
  }
}
