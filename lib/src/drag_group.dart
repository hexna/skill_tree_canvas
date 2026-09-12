import 'dart:ui';

/// 拖拽分组：拖动一个节点时，跟着一起走的节点集合。
class SkillDragGroup {
  const SkillDragGroup._();

  /// 与 [rootId] 直接或间接相连的整块（不管方向）。
  static Set<int> component(int rootId, List<(int, int)> links) {
    final neighbors = <int, Set<int>>{};
    for (final (first, second) in links) {
      neighbors.putIfAbsent(first, () => {}).add(second);
      neighbors.putIfAbsent(second, () => {}).add(first);
    }
    final result = <int>{rootId};
    final pending = <int>[rootId];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final neighbor in neighbors[current] ?? const <int>{}) {
        if (result.add(neighbor)) pending.add(neighbor);
      }
    }
    return result;
  }

  /// [rootId] 自己加上它的所有后代。
  static Set<int> descendants(int rootId, List<(int, int)> links) {
    final children = <int, List<int>>{};
    for (final (parentId, childId) in links) {
      children.putIfAbsent(parentId, () => []).add(childId);
    }
    final result = <int>{rootId};
    final pending = <int>[rootId];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final childId in children[current] ?? const <int>[]) {
        if (result.add(childId)) pending.add(childId);
      }
    }
    return result;
  }

  static Map<int, Offset> translate({
    required Map<int, Offset> positions,
    required Set<int> group,
    required Offset delta,
  }) {
    return {
      for (final entry in positions.entries)
        entry.key:
            group.contains(entry.key) ? entry.value + delta : entry.value,
    };
  }
}
