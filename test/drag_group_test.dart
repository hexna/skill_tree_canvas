import 'package:flutter_test/flutter_test.dart';
import 'package:skill_tree_canvas/skill_tree_canvas.dart';

void main() {
  test('拖父节点会带上所有后代', () {
    expect(
      SkillDragGroup.descendants(1, const [(1, 2), (2, 3), (4, 5)]),
      {1, 2, 3},
    );
  });

  test('整块连通分量不分方向', () {
    expect(
      SkillDragGroup.component(2, const [(1, 2), (2, 3), (4, 5)]),
      {1, 2, 3},
    );
  });

  test('整组按同一个位移平移', () {
    final result = SkillDragGroup.translate(
      positions: {
        1: const Offset(100, 100),
        2: const Offset(200, 200),
        3: const Offset(400, 400),
      },
      group: const {1, 2},
      delta: const Offset(30, -10),
    );

    expect(result[1], const Offset(130, 90));
    expect(result[2], const Offset(230, 190));
    expect(result[3], const Offset(400, 400));
  });
}
