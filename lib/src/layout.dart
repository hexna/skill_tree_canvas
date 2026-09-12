import 'dart:ui';

import 'models.dart';

/// 初始播种：同一层级的节点排进同一竖列，层级越高越靠右。
///
/// 这里只负责给出一个整齐的起点，后续由 `SkillForceLayout` 的力导向模拟继续演化；
/// 层级的列锚点与 `SkillForceLayout` 的层级重力共用同一组常量。
class SkillTreeLayout {
  const SkillTreeLayout._();

  static const double originX = 220;
  static const double originY = 300;

  /// 层级列间距，同时是层级重力的锚点间距。
  static const double levelColumnGap = 260;

  /// 同层节点之间的纵向间距。
  static const double nodeRowGap = 180;

  static Map<int, Offset> seed(Iterable<SkillNode> nodes) {
    final byLevel = <int, List<int>>{};
    for (final node in nodes) {
      byLevel.putIfAbsent(node.level, () => []).add(node.id);
    }
    final positions = <int, Offset>{};
    for (final entry in byLevel.entries) {
      final ids = entry.value;
      final startY = originY - (ids.length - 1) * nodeRowGap / 2;
      for (var index = 0; index < ids.length; index++) {
        positions[ids[index]] = Offset(
          originX + (entry.key - 1) * levelColumnGap,
          startY + index * nodeRowGap,
        );
      }
    }
    return positions;
  }

  /// 某个层级在 x 轴上的列锚点。
  static double columnAnchor(int level) =>
      originX + (level - 1) * levelColumnGap;
}
