import 'package:flutter_test/flutter_test.dart';
import 'package:skill_tree_canvas/skill_tree_canvas.dart';

void main() {
  test('同层级排进同一竖列，层级越高越靠右', () {
    final nodes = [
      const SkillNode(id: 1, label: '根', level: 1),
      const SkillNode(id: 2, label: 'A', level: 2),
      const SkillNode(id: 3, label: 'B', level: 2),
      const SkillNode(id: 4, label: 'C', level: 3),
    ];

    final positions = SkillTreeLayout.seed(nodes);

    expect(positions.keys, containsAll([1, 2, 3, 4]));
    expect(positions[2]!.dx, positions[3]!.dx);
    expect(positions[1]!.dx, SkillTreeLayout.columnAnchor(1));
    expect(positions[4]!.dx, SkillTreeLayout.columnAnchor(3));
    expect(positions[2]!.dy, isNot(positions[3]!.dy));
  });

  test('空图不炸', () {
    expect(SkillTreeLayout.seed(const []), isEmpty);
  });
}
