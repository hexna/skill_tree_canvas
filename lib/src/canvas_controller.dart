import 'package:flutter/widgets.dart';

import 'canvas_settings.dart';
import 'physics_dialog.dart';

/// 画布对外的遥控器：给宿主 App 的工具栏 / 手势按钮用。
///
/// 挂到 [SkillTreeCanvas.controller] 上之后可以重置视图、按 focal point 缩放、
/// 开关节点拖动、改物理参数（会写回 [SkillTreeSettingsStore]）、重新播种布局。
class SkillTreeCanvasController extends ChangeNotifier {
  SkillTreeCanvasDelegate? _delegate;

  /// 由 `SkillTreeCanvas` 调用，业务代码不要手动调。
  void attach(SkillTreeCanvasDelegate delegate) {
    _delegate = delegate;
  }

  /// 由 `SkillTreeCanvas` 调用，业务代码不要手动调。
  void detach(SkillTreeCanvasDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }

  /// 当前缩放倍数。
  double get scale => _delegate?.scale ?? 1;

  /// 当前平移量（屏幕坐标）。
  Offset get offset => _delegate?.offset ?? Offset.zero;

  /// 是否处于「拖动节点」模式；关闭时在画布上拖动是平移视图。
  bool get dragNodesEnabled => _delegate?.dragNodesEnabled ?? false;

  /// 当前生效的物理参数。
  SkillTreeCanvasSettings get settings =>
      _delegate?.settings ?? SkillTreeCanvasSettings.defaults;

  /// 回到 1:1 且不偏移。
  void resetView() => _delegate?.resetView();

  /// 缩放到 [scale]；[focalPoint] 是保持不动的屏幕点，默认画布中心。
  void zoomTo(double scale, {Offset? focalPoint}) =>
      _delegate?.zoomTo(scale, focalPoint);

  void setDragNodesEnabled(bool value) => _delegate?.setDragNodesEnabled(value);

  /// 应用新的物理参数（按键的 store 持久化由画布负责）。
  Future<void> applySettings(SkillTreeCanvasSettings settings) async =>
      _delegate?.applySettings(settings);

  /// 丢掉当前节点位置，按层级重新播种再跑一次力导向。
  void relayout() => _delegate?.relayout();

  /// 弹出「画布物理参数」面板并应用结果。
  Future<void> openSettingsDialog(BuildContext context) async {
    final delegate = _delegate;
    if (delegate == null) return;
    final next = await showSkillTreePhysicsDialog(
      context,
      settings: delegate.settings,
    );
    if (next == null) return;
    await delegate.applySettings(next);
  }

  /// 画布视图（缩放 / 偏移 / 拖动模式）变化时由 `SkillTreeCanvas` 触发。
  /// 宿主监听控制器即可刷新「当前 200%」这类显示。
  void notifyViewChanged() => notifyListeners();
}

/// 画布与控制器之间的内部契约，由 `SkillTreeCanvas` 自己实现；业务代码不要实现它。
abstract class SkillTreeCanvasDelegate {
  double get scale;
  Offset get offset;
  bool get dragNodesEnabled;
  SkillTreeCanvasSettings get settings;

  void resetView();

  void zoomTo(double scale, Offset? focalPoint);

  void setDragNodesEnabled(bool value);

  Future<void> applySettings(SkillTreeCanvasSettings settings);

  void relayout();
}
