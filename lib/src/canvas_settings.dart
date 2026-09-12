import 'package:flutter/foundation.dart';

/// 画布物理参数。值越大节点越分散 / 惯性越持久，可在「画布物理参数」面板里调。
@immutable
class SkillTreeCanvasSettings {
  const SkillTreeCanvasSettings({
    required this.repulsion,
    required this.collisionDistance,
    required this.damping,
    this.levelGravity = 0.0025,
  });

  static const defaults = SkillTreeCanvasSettings(
    repulsion: 2500,
    collisionDistance: 50,
    damping: 0.78,
  );

  /// 节点两两斥力。越大越分散。
  final double repulsion;

  /// 碰撞距离（px）。节点矩形之间保留的空隙。
  final double collisionDistance;

  /// 速度阻尼。越大惯性越持久、越"重"。
  final double damping;

  /// 层级重力基准强度：按 level 线性放大，把节点吸回各自的层级列，0 为关闭。
  final double levelGravity;

  SkillTreeCanvasSettings copyWith({
    double? repulsion,
    double? collisionDistance,
    double? damping,
    double? levelGravity,
  }) =>
      SkillTreeCanvasSettings(
        repulsion: repulsion ?? this.repulsion,
        collisionDistance: collisionDistance ?? this.collisionDistance,
        damping: damping ?? this.damping,
        levelGravity: levelGravity ?? this.levelGravity,
      );

  @override
  bool operator ==(Object other) =>
      other is SkillTreeCanvasSettings &&
      other.repulsion == repulsion &&
      other.collisionDistance == collisionDistance &&
      other.damping == damping &&
      other.levelGravity == levelGravity;

  @override
  int get hashCode =>
      Object.hash(repulsion, collisionDistance, damping, levelGravity);
}

/// 物理参数的持久化接口：想记住用户调过的参数就实现它（写 prefs / 数据库 / 文件都行），
/// 不传就每次用 [SkillTreeCanvasSettings.defaults]。
abstract class SkillTreeSettingsStore {
  Future<SkillTreeCanvasSettings> load();

  Future<void> save(SkillTreeCanvasSettings settings);
}

/// 只活在内存里的实现，适合示例、测试，或不需要持久化的场景。
class InMemorySkillTreeSettingsStore implements SkillTreeSettingsStore {
  InMemorySkillTreeSettingsStore([
    this._settings = SkillTreeCanvasSettings.defaults,
  ]);

  SkillTreeCanvasSettings _settings;

  SkillTreeCanvasSettings get settings => _settings;

  @override
  Future<SkillTreeCanvasSettings> load() async => _settings;

  @override
  Future<void> save(SkillTreeCanvasSettings settings) async {
    _settings = settings;
  }
}
