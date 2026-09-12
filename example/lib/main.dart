import 'package:flutter/material.dart';
import 'package:skill_tree_canvas/skill_tree_canvas.dart';

void main() => runApp(const SkillTreeCanvasDemoApp());

class SkillTreeCanvasDemoApp extends StatelessWidget {
  const SkillTreeCanvasDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '技能树画布 Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E88E5),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E88E5),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const CanvasDemoPage(),
    );
  }
}

// ── 一份示例图：数学基础 → 三个分支 → 各自的技能点 ────────────────────────────
const List<SkillNode> _sampleNodes = [
  SkillNode(id: 1, label: '数学基础', level: 1, kind: SkillNodeKind.group),
  SkillNode(id: 2, label: '代数', level: 2),
  SkillNode(id: 3, label: '几何', level: 2),
  SkillNode(id: 4, label: '概率统计', level: 2),
  SkillNode(id: 5, label: '方程', level: 3),
  SkillNode(id: 6, label: '函数', level: 3),
  SkillNode(id: 7, label: '三角形', level: 3),
  SkillNode(id: 8, label: '圆', level: 3),
  SkillNode(id: 9, label: '随机变量', level: 3),
  SkillNode(id: 10, label: '分布', level: 3),
  SkillNode(id: 11, label: '一元二次方程', level: 4),
  SkillNode(id: 12, label: '指数与对数', level: 4),
  SkillNode(id: 13, label: '勾股定理', level: 4),
  SkillNode(id: 14, label: '圆的性质', level: 4),
  SkillNode(id: 15, label: '期望与方差', level: 4),
  SkillNode(id: 16, label: '正态分布', level: 4),
];

const List<SkillLink> _links = [
  SkillLink(parentId: 1, childId: 2),
  SkillLink(parentId: 1, childId: 3),
  SkillLink(parentId: 1, childId: 4),
  SkillLink(parentId: 2, childId: 5),
  SkillLink(parentId: 2, childId: 6),
  SkillLink(parentId: 3, childId: 7),
  SkillLink(parentId: 3, childId: 8),
  SkillLink(parentId: 4, childId: 9),
  SkillLink(parentId: 4, childId: 10),
  SkillLink(parentId: 5, childId: 11),
  SkillLink(parentId: 6, childId: 12),
  SkillLink(parentId: 7, childId: 13),
  SkillLink(parentId: 8, childId: 14),
  SkillLink(parentId: 9, childId: 15),
  SkillLink(parentId: 10, childId: 16),
];

class CanvasDemoPage extends StatefulWidget {
  const CanvasDemoPage({super.key});

  @override
  State<CanvasDemoPage> createState() => _CanvasDemoPageState();
}

class _CanvasDemoPageState extends State<CanvasDemoPage> {
  final SkillTreeCanvasController _controller = SkillTreeCanvasController();
  final Map<int, Offset> _savedPositions = {};
  final _DemoSettingsStore _settingsStore = _DemoSettingsStore();

  /// 拿掌握度当状态色的示例（真实项目里可以换成记忆度 / 正确率 / 完成度）。
  final Map<int, double> _mastery = {
    for (final node in _sampleNodes) node.id: (node.id * 37 % 100) / 100,
  };

  late List<SkillNode> _nodes = List.of(_sampleNodes);
  bool _colorByMastery = false;
  bool _dragNodes = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SkillTreeNodeStyle _masteryStyle(SkillNode node, ColorScheme scheme) {
    if (node.kind == SkillNodeKind.group) {
      return defaultSkillTreeNodeStyle(node, scheme);
    }
    final value = _mastery[node.id] ?? 0.5;
    if (value < 0.4) {
      return SkillTreeNodeStyle(
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      );
    }
    if (value < 0.7) {
      return SkillTreeNodeStyle(
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      );
    }
    return SkillTreeNodeStyle(
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
    );
  }

  void _onNodeDragEnd(Map<int, Offset> moved) {
    setState(() {
      _savedPositions.addAll(moved);
      _nodes = [
        for (final node in _nodes)
          _savedPositions[node.id] == null
              ? node
              : node.copyWith(
                  x: _savedPositions[node.id]!.dx,
                  y: _savedPositions[node.id]!.dy,
                ),
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已交出 ${moved.length} 个节点的最终坐标，宿主自己决定存哪里'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('技能树画布 Demo'),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${(_controller.scale * 100).round()}%'),
              ),
            ),
          ),
          IconButton(
            tooltip: '重置视图',
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _controller.resetView,
          ),
          IconButton(
            tooltip: '按层级重新布局',
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            onPressed: _controller.relayout,
          ),
          IconButton(
            tooltip: _colorByMastery ? '当前：按掌握度着色' : '当前：按层级着色',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => setState(() => _colorByMastery = !_colorByMastery),
          ),
          IconButton(
            tooltip: '画布物理参数',
            icon: const Icon(Icons.tune),
            onPressed: () => _controller.openSettingsDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SkillTreeCanvas(
            controller: _controller,
            nodes: _nodes,
            links: _links,
            theme: SkillTreeCanvasTheme(
              nodeStyleBuilder:
                  _colorByMastery ? _masteryStyle : defaultSkillTreeNodeStyle,
            ),
            settingsStore: _settingsStore,
            onNodeTap: (node) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('点到了 ${node.level}. ${node.label}'),
                duration: const Duration(seconds: 1),
              ),
            ),
            onNodeDragEnd: _onNodeDragEnd,
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: IgnorePointer(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '拖动空白处平移 · 双指或双击缩放\n'
                    '点节点触发 onNodeTap · 右下角开启节点拖动\n'
                    '拖动节点会把它的后代一起甩出去',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final next = !_dragNodes;
          _controller.setDragNodesEnabled(next);
          setState(() => _dragNodes = next);
        },
        icon: Icon(_dragNodes ? Icons.pan_tool : Icons.open_with),
        label: Text(_dragNodes ? '移动节点中' : '开启节点拖动'),
      ),
    );
  }
}

/// 演示用：把物理参数记在内存里（换成 SharedPreferences / 文件都行）。
class _DemoSettingsStore implements SkillTreeSettingsStore {
  SkillTreeCanvasSettings _settings = SkillTreeCanvasSettings.defaults;

  @override
  Future<SkillTreeCanvasSettings> load() async => _settings;

  @override
  Future<void> save(SkillTreeCanvasSettings settings) async {
    _settings = settings;
  }
}
