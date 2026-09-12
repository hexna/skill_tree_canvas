import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'canvas_controller.dart';
import 'canvas_settings.dart';
import 'canvas_theme.dart';
import 'drag_group.dart';
import 'force_layout.dart';
import 'layout.dart';
import 'models.dart';
import 'tree_painter.dart';

/// 力导向技能树画布：平移、捏合缩放、双击放大、悬停高亮、按层级重力自动分列、
/// 可拖动节点（连同它的后代一起被物理引擎甩出去）。
///
/// 它是纯 UI 组件：不认识数据库、AI、题目或任何业务模型，只吃 [nodes] / [links]。
/// 视图操作（重置、缩放、改物理参数）通过 [controller]；节点点击通过 [onNodeTap]。
class SkillTreeCanvas extends StatefulWidget {
  const SkillTreeCanvas({
    super.key,
    required this.nodes,
    required this.links,
    this.controller,
    this.theme = const SkillTreeCanvasTheme(),
    this.settings = SkillTreeCanvasSettings.defaults,
    this.settingsStore,
    this.showLevelBadge = true,
    this.initialDragNodesEnabled = false,
    this.minScale = 0.3,
    this.maxScale = 4.0,
    this.onNodeTap,
    this.onBackgroundTap,
    this.onNodeDragEnd,
  });

  final List<SkillNode> nodes;
  final List<SkillLink> links;
  final SkillTreeCanvasController? controller;

  /// 配色（层级色板 + 节点配色钩子 + 背景渐变）。
  final SkillTreeCanvasTheme theme;

  /// 初始物理参数；接了 [settingsStore] 时会被 store 里的值覆盖。
  final SkillTreeCanvasSettings settings;

  /// 物理参数持久化，可为空。
  final SkillTreeSettingsStore? settingsStore;

  /// 节点文字是否带 `层级.` 前缀。
  final bool showLevelBadge;

  /// 初始是否处于「拖动节点」模式。
  final bool initialDragNodesEnabled;

  final double minScale;
  final double maxScale;

  /// 单击节点（双击缩放不会触发）。
  final ValueChanged<SkillNode>? onNodeTap;

  final VoidCallback? onBackgroundTap;

  /// 拖拽结束：交出被拖动分组里每个节点的最终世界坐标，宿主自己决定要不要存。
  final ValueChanged<Map<int, Offset>>? onNodeDragEnd;

  @override
  State<SkillTreeCanvas> createState() => _SkillTreeCanvasState();
}

class _SkillTreeCanvasState extends State<SkillTreeCanvas>
    with SingleTickerProviderStateMixin
    implements SkillTreeCanvasDelegate {
  double _scale = 1;
  Offset _offset = Offset.zero;
  bool _dragNodes = false;
  late SkillTreeCanvasSettings _canvasSettings;

  double _scaleAtGestureStart = 1;
  Offset _offsetAtGestureStart = Offset.zero;

  int? _draggedId;
  int? _hoveredId;
  int? _nodePointerId;
  Set<int> _dragGroup = const {};
  Offset _dragStartFocal = Offset.zero;
  Offset _dragOrigin = Offset.zero;
  Offset _lastDragDelta = Offset.zero;
  bool _dragImpulseApplied = false;
  bool _scaling = false;
  final Set<int> _activePointers = {};
  final Map<int, Offset> _pointerPositions = {};
  Offset _gestureStart = Offset.zero;
  Offset _lastFocal = Offset.zero;
  Offset _pinchAnchor = Offset.zero;
  double _pinchStartDistance = 0;
  double _pinchStartScale = 1;
  bool _gestureMoved = false;

  DateTime? _lastTapAt;
  Offset _lastTapPosition = Offset.zero;
  Offset _pendingTapPosition = Offset.zero;
  Timer? _tapTimer;

  /// 世界坐标：唯一的绘制/命中数据源。
  final Map<int, Offset> _positions = {};
  final Map<int, Offset> _velocities = {};
  final Set<int> _pinnedNodes = {};
  List<(int, int)> _linkPairs = const [];
  Map<int, int> _levels = const {};
  String _linkSignature = '';
  Size _canvasSize = Size.zero;
  int _stableLayoutFrames = 0;

  final ValueNotifier<int> _layoutRepaint = ValueNotifier(0);
  late final Ticker _layoutTicker;
  Duration _lastLayoutElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _canvasSettings = widget.settings;
    _dragNodes = widget.initialDragNodesEnabled;
    _layoutTicker = createTicker(_onLayoutTick);
    widget.controller?.attach(this);
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLayout();
      _ensureTicker();
    });
  }

  @override
  void didUpdateWidget(covariant SkillTreeCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (oldWidget.settings != widget.settings) {
      _canvasSettings = widget.settings;
      _wakeLayout();
    }
    if (!identical(oldWidget.nodes, widget.nodes) ||
        !identical(oldWidget.links, widget.links)) {
      _syncLayout();
      _ensureTicker();
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _layoutTicker.dispose();
    _layoutRepaint.dispose();
    widget.controller?.detach(this);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final store = widget.settingsStore;
    if (store == null) return;
    final saved = await store.load();
    if (!mounted || saved == _canvasSettings) return;
    setState(() => _canvasSettings = saved);
    _wakeLayout();
  }

  // ── 控制器接口 ────────────────────────────────────────────────────────────

  @override
  double get scale => _scale;

  @override
  Offset get offset => _offset;

  @override
  bool get dragNodesEnabled => _dragNodes;

  @override
  SkillTreeCanvasSettings get settings => _canvasSettings;

  @override
  void resetView() {
    setState(() {
      _scale = 1;
      _offset = Offset.zero;
    });
    widget.controller?.notifyViewChanged();
  }

  @override
  void zoomTo(double scale, Offset? focalPoint) =>
      _zoomTo(scale, focalPoint ?? _canvasSize.center(Offset.zero));

  @override
  void setDragNodesEnabled(bool value) {
    if (_dragNodes == value) return;
    if (!value && _draggedId != null) {
      _nodePointerId = null;
      _finishNodeDrag();
    }
    setState(() => _dragNodes = value);
    widget.controller?.notifyViewChanged();
  }

  @override
  Future<void> applySettings(SkillTreeCanvasSettings settings) async {
    if (settings == _canvasSettings) return;
    setState(() => _canvasSettings = settings);
    await widget.settingsStore?.save(settings);
    _wakeLayout();
  }

  @override
  void relayout() {
    _positions.clear();
    _velocities.clear();
    _pinnedNodes.clear();
    _stableLayoutFrames = 0;
    _syncLayout();
    if (mounted) setState(() {});
    _ensureTicker();
  }

  void _zoomTo(double targetScale, Offset focalPoint) {
    final next = targetScale.clamp(widget.minScale, widget.maxScale).toDouble();
    final worldAtFocal = (focalPoint - _offset) / _scale;
    setState(() {
      _scale = next;
      _offset = focalPoint - worldAtFocal * next;
    });
    widget.controller?.notifyViewChanged();
  }

  // ── 力导向模拟 ────────────────────────────────────────────────────────────

  void _onLayoutTick(Duration elapsed) {
    if (!mounted || _positions.isEmpty || _canvasSize.isEmpty) return;
    final dt = (elapsed - _lastLayoutElapsed).inMicroseconds / 1000000;
    _lastLayoutElapsed = elapsed;
    final before = Map<int, Offset>.from(_positions);
    SkillForceLayout.step(
      positions: _positions,
      velocities: _velocities,
      links: _linkPairs,
      pinned: _pinnedNodes,
      bounds: _canvasSize,
      dt: dt.clamp(0.001, 0.05).toDouble(),
      repulsion: _canvasSettings.repulsion,
      collisionDistance: _canvasSettings.collisionDistance,
      damping: _canvasSettings.damping,
      levels: _levels,
      levelGravity: _canvasSettings.levelGravity,
    );
    _layoutRepaint.value++;
    final maxMovement = before.keys.fold<double>(0, (maximum, id) {
      final movement = (before[id]! - _positions[id]!).distance;
      return movement > maximum ? movement : maximum;
    });
    final maxVelocity = _velocities.values.fold<double>(0, (maximum, value) {
      final speed = value.distance;
      return speed > maximum ? speed : maximum;
    });
    if (maxMovement < 0.35 && maxVelocity < 0.35) {
      _stableLayoutFrames++;
      if (_stableLayoutFrames >= 8) {
        _velocities.updateAll((id, _) => Offset.zero);
        _layoutTicker.stop();
      }
    } else {
      _stableLayoutFrames = 0;
    }
  }

  void _ensureTicker() {
    if (_positions.isEmpty || _layoutTicker.isActive || _canvasSize.isEmpty) {
      return;
    }
    _lastLayoutElapsed = Duration.zero;
    _layoutTicker.start();
  }

  /// 参数或节点变了：清掉稳定计数再跑一轮。
  void _wakeLayout() {
    _stableLayoutFrames = 0;
    _ensureTicker();
  }

  void _syncLayout() {
    final nodes = widget.nodes;
    final links = widget.links;
    final signature = links
        .map((link) => '${link.parentId}:${link.childId}:${link.weight}')
        .join('|');
    if (signature != _linkSignature) {
      _linkSignature = signature;
      _stableLayoutFrames = 0;
    }
    _linkPairs = links.map((link) => link.pair).toList(growable: false);
    _levels = {for (final node in nodes) node.id: node.level};
    final seeded = SkillTreeLayout.seed(nodes);
    final ids = nodes.map((node) => node.id).toSet();
    _positions.removeWhere((id, _) => !ids.contains(id));
    _velocities.removeWhere((id, _) => !ids.contains(id));
    _pinnedNodes.removeWhere((id) => !ids.contains(id));
    for (final node in nodes) {
      if (_positions.containsKey(node.id)) continue;
      _positions[node.id] = node.position ?? seeded[node.id] ?? Offset.zero;
      _stableLayoutFrames = 0;
    }
  }

  // ── 手势 ──────────────────────────────────────────────────────────────────

  void _handlePointerDown(int pointer, Offset position) {
    _pointerPositions[pointer] = position;
    _activePointers.add(pointer);
    if (_activePointers.length == 1) {
      _gestureStart = position;
      _lastFocal = position;
      _gestureMoved = false;
      _scaling = false;
      if (_dragNodes) {
        final id = _hit(position);
        if (id != null) {
          _beginNodeDrag(id, position);
          _nodePointerId = pointer;
        }
      }
      return;
    }
    if (_activePointers.length == 2) {
      _scaling = true;
      _gestureMoved = true;
      if (_draggedId != null) {
        _draggedId = null;
        _nodePointerId = null;
        _dragGroup = const {};
      }
      final points = _pointerPositions.values.take(2).toList(growable: false);
      _pinchAnchor = Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
      _pinchStartDistance = (points[0] - points[1]).distance;
      _pinchStartScale = _scale;
      _scaleAtGestureStart = _scale;
      _offsetAtGestureStart = _offset;
    }
  }

  void _handlePointerMove(int pointer, Offset position) {
    if (!_pointerPositions.containsKey(pointer)) return;
    _pointerPositions[pointer] = position;
    if (_activePointers.length >= 2) {
      final points = _activePointers
          .map((id) => _pointerPositions[id])
          .whereType<Offset>()
          .take(2)
          .toList(growable: false);
      if (points.length < 2 || _pinchStartDistance <= 0) return;
      final focal = Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
      final distance = (points[0] - points[1]).distance;
      final nextScale = (_pinchStartScale * distance / _pinchStartDistance)
          .clamp(widget.minScale, widget.maxScale)
          .toDouble();
      final worldAtAnchor =
          (_pinchAnchor - _offsetAtGestureStart) / _scaleAtGestureStart;
      setState(() {
        _scale = nextScale;
        _offset = focal - worldAtAnchor * nextScale;
      });
      _lastFocal = focal;
      return;
    }
    final delta = position - _gestureStart;
    if (delta.distance > 8) _gestureMoved = true;
    if (_draggedId != null && pointer == _nodePointerId) {
      _updateNodeDrag(position);
      return;
    }
    if (_gestureMoved) {
      final pan = position - _lastFocal;
      setState(() => _offset += pan);
    }
    _lastFocal = position;
  }

  void _handlePointerUp(int pointer, Offset position) {
    _pointerPositions.remove(pointer);
    _activePointers.remove(pointer);
    if (pointer == _nodePointerId) {
      _nodePointerId = null;
      _finishNodeDrag();
    }
    if (_activePointers.isNotEmpty) {
      _lastFocal = _pointerPositions[_activePointers.first] ?? position;
      return;
    }
    final wasScaling = _scaling;
    _scaling = false;
    if (wasScaling || _gestureMoved) return;
    _handleTap(position);
  }

  void _handlePointerCancel(int pointer) {
    _pointerPositions.remove(pointer);
    _activePointers.remove(pointer);
    if (pointer == _nodePointerId) {
      _nodePointerId = null;
      _finishNodeDrag();
    }
    if (_activePointers.isEmpty) _scaling = false;
  }

  /// 单击要等一个双击窗口，避免「点一下节点」和「双击放大」抢同一手势。
  void _handleTap(Offset position) {
    final now = DateTime.now();
    final isDoubleTap = _lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < 300 &&
        (position - _lastTapPosition).distance < 60;
    if (isDoubleTap) {
      _lastTapAt = null;
      _tapTimer?.cancel();
      _tapTimer = null;
      _zoomTo(_scale > 1.5 ? 1.0 : 2.0, position);
      return;
    }
    _lastTapAt = now;
    _lastTapPosition = position;
    _pendingTapPosition = position;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 260), () {
      _tapTimer = null;
      if (!mounted || _dragNodes) return;
      final id = _hit(_pendingTapPosition);
      if (id == null) {
        widget.onBackgroundTap?.call();
        return;
      }
      for (final node in widget.nodes) {
        if (node.id != id) continue;
        widget.onNodeTap?.call(node);
        break;
      }
    });
  }

  // ── 节点拖拽 ──────────────────────────────────────────────────────────────

  void _beginNodeDrag(int id, Offset focalPoint) {
    _draggedId = id;
    _dragStartFocal = focalPoint;
    _dragOrigin = _positions[id] ?? Offset.zero;
    _lastDragDelta = Offset.zero;
    _dragImpulseApplied = false;
    _dragGroup = SkillDragGroup.descendants(id, _linkPairs)
        .intersection(widget.nodes.map((node) => node.id).toSet());
    _pinnedNodes.clear();
    _pinnedNodes.add(id);
    setState(() {});
  }

  void _updateNodeDrag(Offset focalPoint) {
    final id = _draggedId;
    if (id == null) return;
    final delta = (focalPoint - _dragStartFocal) / _scale;
    final pointerDelta = delta - _lastDragDelta;
    if (!_dragImpulseApplied && pointerDelta.distance > 0.1) {
      for (final childId in _dragGroup.where((childId) => childId != id)) {
        _velocities[childId] =
            (_velocities[childId] ?? Offset.zero) - pointerDelta * 0.35;
      }
      _dragImpulseApplied = true;
    }
    _velocities[id] = pointerDelta;
    _lastDragDelta = delta;
    if (!mounted) return;
    setState(() => _positions[id] = _dragOrigin + delta);
    _ensureTicker();
  }

  void _finishNodeDrag() {
    final id = _draggedId;
    if (id == null) return;
    final group = _dragGroup;
    final moved = <int, Offset>{
      for (final groupId in group)
        if (_positions[groupId] != null) groupId: _positions[groupId]!,
    };
    _draggedId = null;
    _dragGroup = const {};
    if (moved.isEmpty) return;
    _pinnedNodes.removeAll(group);
    _pinnedNodes.add(id);
    if (mounted) setState(() {});
    widget.onNodeDragEnd?.call(moved);
    _ensureTicker();
  }

  int? _hit(Offset point) {
    final world = (point - _offset) / _scale;
    for (final node in widget.nodes.reversed) {
      final position = _positions[node.id] ?? node.position;
      if (position == null) continue;
      if ((position - world).distance <= kSkillNodeHitRadius) return node.id;
    }
    return null;
  }

  // ── 绘制 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size.isFinite && size != _canvasSize) {
        _canvasSize = size;
        _ensureTicker();
      }
      return MouseRegion(
        cursor: _dragNodes
            ? SystemMouseCursors.grab
            : _hoveredId != null
                ? SystemMouseCursors.click
                : MouseCursor.defer,
        onHover: (event) {
          final id = _hit(event.localPosition);
          if (id != _hoveredId) setState(() => _hoveredId = id);
        },
        onExit: (_) {
          if (_hoveredId != null) setState(() => _hoveredId = null);
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) =>
              _handlePointerDown(event.pointer, event.localPosition),
          onPointerMove: (event) =>
              _handlePointerMove(event.pointer, event.localPosition),
          onPointerUp: (event) =>
              _handlePointerUp(event.pointer, event.localPosition),
          onPointerCancel: (event) => _handlePointerCancel(event.pointer),
          child: CustomPaint(
            painter: SkillTreePainter(
              nodes: widget.nodes,
              links: widget.links,
              theme: widget.theme,
              colorScheme: colorScheme,
              offset: _offset,
              scale: _scale,
              positions: _positions,
              highlightedId: _draggedId ?? _hoveredId,
              textDirection:
                  Directionality.maybeOf(context) ?? TextDirection.ltr,
              showLevelBadge: widget.showLevelBadge,
              repaint: _layoutRepaint,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    });
  }
}
