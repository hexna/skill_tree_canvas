import 'dart:ui';

/// 节点类型。`group` 只是默认配色不同的分组/主题节点，画布本身不做区分，
/// 具体外观由 [SkillTreeCanvasTheme.nodeStyleBuilder] 决定。
enum SkillNodeKind { skill, group }

/// 画布上的一个节点。
///
/// [id] 在整张图里必须唯一；[level] 从 1 开始，既决定层级重力的列锚点，
/// 也决定默认配色。[x]/[y] 是持久化的位置，为空时由自动布局播种。
class SkillNode {
  const SkillNode({
    required this.id,
    required this.label,
    this.level = 1,
    this.x,
    this.y,
    this.kind = SkillNodeKind.skill,
  });

  final int id;
  final String label;
  final int level;
  final double? x;
  final double? y;
  final SkillNodeKind kind;

  Offset? get position =>
      (x == null || y == null) ? null : Offset(x!.toDouble(), y!.toDouble());

  SkillNode copyWith({
    String? label,
    int? level,
    double? x,
    double? y,
    SkillNodeKind? kind,
  }) =>
      SkillNode(
        id: id,
        label: label ?? this.label,
        level: level ?? this.level,
        x: x ?? this.x,
        y: y ?? this.y,
        kind: kind ?? this.kind,
      );

  @override
  bool operator ==(Object other) =>
      other is SkillNode &&
      other.id == id &&
      other.label == label &&
      other.level == level &&
      other.x == x &&
      other.y == y &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, label, level, x, y, kind);
}

/// 一条有向连线：parent → child。
class SkillLink {
  const SkillLink({
    required this.parentId,
    required this.childId,
    this.weight = 1,
  });

  final int parentId;
  final int childId;
  final double weight;

  (int, int) get pair => (parentId, childId);

  @override
  bool operator ==(Object other) =>
      other is SkillLink &&
      other.parentId == parentId &&
      other.childId == childId &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(parentId, childId, weight);
}
