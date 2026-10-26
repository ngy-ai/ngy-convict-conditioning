/// 一式的详细指导，对应原书每式的四个部分：
/// 动作、解析、训练目标（用 [ProgressionStandard] 表示）、稳扎稳打。
///
/// 文案是对原书对应小节的改写与压缩，只保留动作要点与训练提示，不含原书插图。
class MoveGuide {
  const MoveGuide({
    required this.action,
    required this.analysis,
    required this.progression,
  });

  /// 动作：起始姿势、动作过程与结束姿势。
  final String action;

  /// 解析：这一式在十式中的位置、技术要点与常见问题。
  final String analysis;

  /// 稳扎稳打：做不动时怎么退阶，以及向下一式过渡的路径。
  final String progression;
}
