import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_tree_canvas/skill_tree_canvas.dart';

void main() {
  test('相连的两个节点会被弹簧拉近', () {
    final before = {
      1: const Offset(100, 100),
      2: const Offset(500, 100),
    };
    final after = SkillForceLayout.step(
      positions: before,
      links: const [(1, 2)],
      bounds: const Size(800, 500),
      dt: 1 / 60,
    );

    expect((after[1]! - after[2]!).distance, lessThan(400));
  });

  test('固定（拖拽中）的节点不动', () {
    const pinned = Offset(100, 100);
    final after = SkillForceLayout.step(
      positions: {1: pinned, 2: const Offset(500, 100)},
      links: const [(1, 2)],
      pinned: const {1},
      bounds: const Size(800, 500),
      dt: 1 / 60,
    );

    expect(after[1], pinned);
  });

  test('重叠节点按矩形边界被推开', () {
    final positions = {
      1: const Offset(100, 100),
      2: const Offset(110, 100),
    };

    SkillForceLayout.step(
      positions: positions,
      links: const [],
      bounds: const Size(300, 300),
      dt: 1 / 60,
    );

    expect((positions[1]! - positions[2]!).distance, greaterThan(10));
  });

  test('卡片按矩形碰撞，最小间距不小于卡片宽', () {
    final positions = {
      1: const Offset(100, 100),
      2: const Offset(200, 100),
    };

    SkillForceLayout.step(
      positions: positions,
      links: const [],
      bounds: const Size(400, 300),
      repulsion: 0,
      collisionDistance: 0,
      dt: 1 / 60,
    );

    expect(
        (positions[1]!.dx - positions[2]!.dx).abs(), greaterThanOrEqualTo(116));
  });

  test('自由节点会与固定节点分离', () {
    final positions = {
      1: const Offset(100, 100),
      2: const Offset(110, 100),
    };

    SkillForceLayout.step(
      positions: positions,
      links: const [],
      pinned: const {1},
      bounds: const Size(300, 300),
      dt: 1 / 60,
    );

    expect((positions[1]! - positions[2]!).distance, greaterThan(10));
    expect(positions[1], const Offset(100, 100));
  });

  test('节点不会被夹在画布边界内', () {
    final positions = {1: const Offset(-100, -100)};

    SkillForceLayout.step(
      positions: positions,
      links: const [],
      bounds: const Size(300, 300),
    );

    expect(positions[1]!.dx, lessThan(0));
    expect(positions[1]!.dy, lessThan(0));
  });

  test('层级重力把不同层级拉回各自的列锚点', () {
    final positions = {
      1: const Offset(0, 300),
      2: const Offset(900, 300),
    };

    for (var frame = 0; frame < 400; frame++) {
      SkillForceLayout.step(
        positions: positions,
        links: const [],
        bounds: const Size(1200, 800),
        repulsion: 0,
        levels: const {1: 1, 2: 2},
        levelGravity: 0.01,
        dt: 1 / 60,
      );
    }

    expect((positions[1]!.dx - SkillTreeLayout.originX).abs(), lessThan(40));
    expect((positions[2]!.dx - SkillTreeLayout.columnAnchor(2)).abs(),
        lessThan(40));
    expect((positions[2]!.dx - positions[1]!.dx).abs(),
        greaterThan(SkillTreeLayout.levelColumnGap * 0.7));
  });

  test('level 越大层级重力越强', () {
    const bounds = Size(960, 600);
    double displacementAt(int level, double startX) {
      final positions = {1: Offset(startX, 300)};
      SkillForceLayout.step(
        positions: positions,
        links: const [],
        bounds: bounds,
        repulsion: 0,
        levels: {1: level},
        levelGravity: 0.0025,
        dt: 1 / 60,
      );
      return (positions[1]!.dx - startX).abs();
    }

    expect(displacementAt(3, 440), greaterThan(displacementAt(1, 520)));
  });

  test('levelGravity 为 0 时不产生层级约束', () {
    final withLevels = {1: const Offset(700, 300)};
    final withoutLevels = {1: const Offset(700, 300)};

    SkillForceLayout.step(
      positions: withLevels,
      links: const [],
      bounds: const Size(1200, 800),
      repulsion: 0,
      levels: const {1: 3},
      levelGravity: 0,
      dt: 1 / 60,
    );
    SkillForceLayout.step(
      positions: withoutLevels,
      links: const [],
      bounds: const Size(1200, 800),
      repulsion: 0,
      dt: 1 / 60,
    );

    expect(withLevels[1], withoutLevels[1]);
  });
}
