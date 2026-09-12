# skill_tree_canvas_example

`skill_tree_canvas` 的示例工程：一棵 4 层的示例技能树，演示平移缩放、层级重力分列、
节点拖拽与物理参数面板。

```bash
flutter pub get
flutter create --platforms=linux .   # 平台壳子不入库，按需生成（换成 android / windows / macos / web 同理）
flutter run -d linux                 # 或任意已连接的设备
```

页面上的东西全部是「宿主 App 该做的事」，组件本身只管画布：

| 位置 | 用了什么 |
| --- | --- |
| 标题栏百分比 | `SkillTreeCanvasController` + `AnimatedBuilder` |
| 重置视图 / 重新布局 | `controller.resetView()` / `controller.relayout()` |
| 调色板按钮 | `SkillTreeCanvasTheme.nodeStyleBuilder` 换成按掌握度着色 |
| 齿轮按钮 | `controller.openSettingsDialog(context)` |
| 右下角按钮 | `controller.setDragNodesEnabled()` |
| 点节点 | `onNodeTap` |
| 拖完节点 | `onNodeDragEnd` 收回最终坐标，宿主自己决定存哪里 |
