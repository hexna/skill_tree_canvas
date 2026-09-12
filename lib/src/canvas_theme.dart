import 'package:flutter/material.dart';

import 'models.dart';

/// 节点的前景 / 背景配色。
@immutable
class SkillTreeNodeStyle {
  const SkillTreeNodeStyle({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

/// 节点配色钩子：想按「记忆度 / 掌握度 / 状态」上色时改写它。
typedef SkillTreeNodeStyleBuilder = SkillTreeNodeStyle Function(
  SkillNode node,
  ColorScheme scheme,
);

/// 默认层级配色（level 1 起，超出范围的层级取最后一色）。
const List<Color> kSkillTreeLevelColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
];

/// 默认节点配色：分组节点用 tertiaryContainer，普通节点用 surfaceContainerHighest。
/// 想「默认之外再加一种状态色」时可以直接复用它在分支里：
/// ```dart
/// SkillTreeNodeStyle myBuilder(SkillNode node, ColorScheme scheme) =>
///     shouldHighlight(node) ? myStyle : defaultSkillTreeNodeStyle(node, scheme);
/// ```
SkillTreeNodeStyle defaultSkillTreeNodeStyle(
  SkillNode node,
  ColorScheme scheme,
) =>
    node.kind == SkillNodeKind.group
        ? SkillTreeNodeStyle(
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
          )
        : SkillTreeNodeStyle(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
          );

/// 画布主题。默认全部跟随 [ColorScheme]，只覆盖需要改的部分即可。
@immutable
class SkillTreeCanvasTheme {
  const SkillTreeCanvasTheme({
    this.levelColors = kSkillTreeLevelColors,
    this.nodeStyleBuilder = defaultSkillTreeNodeStyle,
    this.backgroundColors,
    this.labelStyle,
  });

  /// 连线与高亮节点用的层级色板。
  final List<Color> levelColors;

  /// 节点配色钩子。
  final SkillTreeNodeStyleBuilder nodeStyleBuilder;

  /// 画布背景渐变（左上 → 右下）。为空时取 `surface → surfaceContainerLow`。
  final List<Color>? backgroundColors;

  /// 节点文字的基准样式。只用来带字体族 / 字重 / 字距这类设置，
  /// 颜色与字号由画布按缩放和高亮状态覆盖。
  final TextStyle? labelStyle;

  Color levelColor(int level) =>
      levelColors[(level - 1).clamp(0, levelColors.length - 1)];

  List<Color> backgroundFor(ColorScheme scheme) =>
      backgroundColors ?? [scheme.surface, scheme.surfaceContainerLow];

  SkillTreeNodeStyle styleFor(SkillNode node, ColorScheme scheme) =>
      nodeStyleBuilder(node, scheme);
}
