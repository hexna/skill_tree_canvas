import 'package:flutter/material.dart';

import 'canvas_settings.dart';

/// 「画布物理参数」面板。返回用户确认后的参数，取消返回 null。
///
/// 直接接在自己的 AppBar / 设置项上即可：
/// ```dart
/// final next = await showSkillTreePhysicsDialog(context, settings: controller.settings);
/// if (next != null) await controller.applySettings(next);
/// ```
Future<SkillTreeCanvasSettings?> showSkillTreePhysicsDialog(
  BuildContext context, {
  required SkillTreeCanvasSettings settings,
}) {
  var draft = settings;
  return showDialog<SkillTreeCanvasSettings>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('画布物理参数'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _settingSlider('斥力', draft.repulsion, 0, 10000, 100,
                  '${draft.repulsion.round()}', (value) {
                setDialogState(() => draft = draft.copyWith(repulsion: value));
              }),
              _settingSlider('碰撞距离', draft.collisionDistance, 20, 120, 50,
                  '${draft.collisionDistance.round()} px', (value) {
                setDialogState(
                    () => draft = draft.copyWith(collisionDistance: value));
              }),
              _settingSlider('阻尼', draft.damping, 0.5, 0.98, 48,
                  draft.damping.toStringAsFixed(2), (value) {
                setDialogState(() => draft = draft.copyWith(damping: value));
              }),
              _settingSlider('层级重力', draft.levelGravity, 0, 0.01, 50,
                  draft.levelGravity.toStringAsFixed(4), (value) {
                setDialogState(
                    () => draft = draft.copyWith(levelGravity: value));
              }),
              const SizedBox(height: 8),
              const Text('斥力和碰撞距离越大，节点越分散；阻尼越大，惯性越持久；'
                  '层级重力越大，各层节点越紧地吸附在自己的竖列里（0 为关闭）。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                setDialogState(() => draft = SkillTreeCanvasSettings.defaults),
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draft),
            child: const Text('应用'),
          ),
        ],
      ),
    ),
  );
}

Widget _settingSlider(
  String label,
  double value,
  double min,
  double max,
  int divisions,
  String valueText,
  ValueChanged<double> onChanged,
) {
  return Column(
    children: [
      Row(children: [Expanded(child: Text(label)), Text(valueText)]),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: valueText,
        onChanged: onChanged,
      ),
    ],
  );
}
