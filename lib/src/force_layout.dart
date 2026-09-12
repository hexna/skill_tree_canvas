import 'dart:math' as math;
import 'dart:ui';

import 'layout.dart';

/// 一步力导向迭代：节点两两斥力 + 矩形碰撞 + 弹簧连线 + 层级重力 + 向中心聚拢。
///
/// 直接原地修改 [positions]（和传入的 [velocities]），画布每帧调用一次即可。
class SkillForceLayout {
  const SkillForceLayout._();

  static const double targetEdgeLength = 190.0;
  static const double nodeRepulsion = 2500.0;
  static const double collisionRadius = 50.0;
  static const double collisionStrength = 0.35;
  static const double nodeHalfWidth = 58.0;
  static const double nodeHalfHeight = 28.0;
  static const double separationEpsilon = 0.1;

  static Map<int, Offset> step({
    required Map<int, Offset> positions,
    Map<int, Offset>? velocities,
    required List<(int, int)> links,
    required Size bounds,
    Set<int> pinned = const {},
    double dt = 1 / 60,
    double repulsion = nodeRepulsion,
    double collisionDistance = collisionRadius,
    double damping = 0.78,
    Map<int, int> levels = const {},
    double levelGravity = 0,
    double levelOriginX = SkillTreeLayout.originX,
    double levelSpacing = SkillTreeLayout.levelColumnGap,
    double edgeLength = targetEdgeLength,
    double halfWidth = nodeHalfWidth,
    double halfHeight = nodeHalfHeight,
  }) {
    final forces = {
      for (final id in positions.keys) id: Offset.zero,
    };
    final nodeVelocities = velocities ?? <int, Offset>{};
    for (final first in positions.keys) {
      for (final second in positions.keys) {
        if (first >= second) continue;
        final delta = positions[first]! - positions[second]!;
        final distance = math.max(delta.distance, 1.0);
        final force = delta / distance * (repulsion / (distance * distance));
        forces[first] = forces[first]! + force;
        forces[second] = forces[second]! - force;
        final padding = collisionDistance * 0.5;
        final overlapX = halfWidth * 2 + padding - delta.dx.abs();
        final overlapY = halfHeight * 2 + padding - delta.dy.abs();
        if (overlapX > 0 && overlapY > 0) {
          final collisionForce = overlapX <= overlapY
              ? Offset(delta.dx == 0 ? 1 : delta.dx.sign, 0) *
                  (overlapX * collisionStrength)
              : Offset(0, delta.dy == 0 ? 1 : delta.dy.sign) *
                  (overlapY * collisionStrength);
          forces[first] = forces[first]! + collisionForce;
          forces[second] = forces[second]! - collisionForce;
        }
      }
    }
    for (final (parentId, childId) in links) {
      final parent = positions[parentId];
      final child = positions[childId];
      if (parent == null || child == null) continue;
      final delta = child - parent;
      final distance = math.max(delta.distance, 1.0);
      final force = delta / distance * ((distance - edgeLength) * 0.018);
      forces[parentId] = forces[parentId]! + force;
      forces[childId] = forces[childId]! - force;
    }
    // 层级重力：把每个节点沿 x 轴拉回自己层级的列锚点，level 越大拉力越强，
    // 不同层级因此自动分成互不重叠的竖列（y 方向保持自由）。
    if (levelGravity > 0) {
      for (final entry in levels.entries) {
        final position = positions[entry.key];
        if (position == null) continue;
        final level = math.max(entry.value, 1);
        final anchorX = levelOriginX + (level - 1) * levelSpacing;
        forces[entry.key] = forces[entry.key]! +
            Offset((anchorX - position.dx) * levelGravity * level, 0);
      }
    }
    final center = Offset(bounds.width / 2, bounds.height / 2);
    for (final id in positions.keys) {
      final velocity = nodeVelocities[id] ?? Offset.zero;
      if (pinned.contains(id)) {
        nodeVelocities[id] = velocity * 0.98;
        continue;
      }
      final force = forces[id]! + (center - positions[id]!) * 0.00035;
      final frameScale = dt * 60;
      var nextVelocity = velocity * damping + force * frameScale;
      final velocityLength = nextVelocity.distance;
      if (velocityLength > 30) {
        nextVelocity = nextVelocity / velocityLength * 30;
      }
      nodeVelocities[id] = nextVelocity;
      final movement = nextVelocity * frameScale;
      final length = movement.distance;
      final limited = length > 18 ? movement / length * 18 : movement;
      final next = positions[id]! + limited;
      forces[id] = limited;
      positions[id] = next;
    }
    _resolveCollisions(
      positions: positions,
      velocities: nodeVelocities,
      pinned: pinned,
      collisionDistance: collisionDistance,
      halfWidth: halfWidth,
      halfHeight: halfHeight,
    );
    return positions;
  }

  static void _resolveCollisions({
    required Map<int, Offset> positions,
    required Map<int, Offset> velocities,
    required Set<int> pinned,
    required double collisionDistance,
    required double halfWidth,
    required double halfHeight,
  }) {
    final padding = collisionDistance * 0.5;
    final width = halfWidth * 2 + padding;
    final height = halfHeight * 2 + padding;
    final ids = positions.keys.toList(growable: false);
    for (var firstIndex = 0; firstIndex < ids.length; firstIndex++) {
      for (var secondIndex = firstIndex + 1;
          secondIndex < ids.length;
          secondIndex++) {
        final first = ids[firstIndex];
        final second = ids[secondIndex];
        final delta = positions[first]! - positions[second]!;
        final overlapX = width - delta.dx.abs();
        final overlapY = height - delta.dy.abs();
        if (overlapX <= 0 || overlapY <= 0) continue;
        final correction = overlapX <= overlapY
            ? Offset(delta.dx == 0 ? 1 : delta.dx.sign, 0) *
                (overlapX + separationEpsilon)
            : Offset(0, delta.dy == 0 ? 1 : delta.dy.sign) *
                (overlapY + separationEpsilon);
        final firstPinned = pinned.contains(first);
        final secondPinned = pinned.contains(second);
        if (!firstPinned && !secondPinned) {
          positions[first] = positions[first]! + correction / 2;
          positions[second] = positions[second]! - correction / 2;
        } else if (!firstPinned) {
          positions[first] = positions[first]! + correction;
        } else if (!secondPinned) {
          positions[second] = positions[second]! - correction;
        }
        if (!firstPinned) {
          velocities[first] = _removeIntoCollision(
            velocities[first] ?? Offset.zero,
            correction,
          );
        }
        if (!secondPinned) {
          velocities[second] = _removeIntoCollision(
            velocities[second] ?? Offset.zero,
            -correction,
          );
        }
      }
    }
  }

  static Offset _removeIntoCollision(Offset velocity, Offset awayDirection) {
    if (awayDirection.dx != 0 && velocity.dx * awayDirection.dx < 0) {
      return Offset(0, velocity.dy);
    }
    if (awayDirection.dy != 0 && velocity.dy * awayDirection.dy < 0) {
      return Offset(velocity.dx, 0);
    }
    return velocity;
  }
}
