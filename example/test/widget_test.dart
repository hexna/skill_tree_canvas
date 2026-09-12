import 'package:flutter_test/flutter_test.dart';
import 'package:skill_tree_canvas/skill_tree_canvas.dart';
import 'package:skill_tree_canvas_example/main.dart';

void main() {
  testWidgets('示例页起得来，画布和工具栏都在', (tester) async {
    await tester.pumpWidget(const SkillTreeCanvasDemoApp());
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(SkillTreeCanvas), findsOneWidget);
    expect(find.text('技能树画布 Demo'), findsOneWidget);
    expect(find.text('开启节点拖动'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('右下角按钮可以切到节点拖动', (tester) async {
    await tester.pumpWidget(const SkillTreeCanvasDemoApp());
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.text('开启节点拖动'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('移动节点中'), findsOneWidget);
  });
}
