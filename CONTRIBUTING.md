# 参与开发

## 提交前

```bash
flutter pub get
dart format lib test example/lib example/test
flutter analyze
flutter test

cd example && flutter pub get && flutter analyze && flutter test
```

CI 会跑上面的全部命令，`dart format` 有改动会直接判失败。

## 约定

- 注释和文档用中文，公开 API 必须有文档注释。
- 对外行为、参数默认值、公开 API 的改动要同时更新 `README.md`、`README.zh-CN.md` 与 `CHANGELOG.md`。
- 物理参数（斥力、碰撞距离、阻尼、层级重力）的默认值是调过手感的，改之前先说明为什么。
- 新增交互要补 `test/tree_canvas_test.dart` 里的 Widget 测试；
  `SkillForceLayout` 这类纯函数改动补 `test/force_layout_test.dart`。

## 报问题

带上：Flutter 版本、节点/边数量级、`SkillTreeCanvasSettings` 的实际取值、录屏或截图。
手感类问题（抖、挤、不跟手）基本都出在参数上，能给出参数值最好。

## 许可

本仓库按 [MIT](LICENSE) 授权。提交 PR 即视为同意自己的贡献同样以 MIT 授权给本项目
（inbound = outbound），不需要单独签署 CLA。
