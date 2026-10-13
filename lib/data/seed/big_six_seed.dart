import '../models/big_six.dart';
import '../models/move.dart';

/// 六艺各十式的动作库。
///
/// 标准数据参考《囚徒健身》给出的各级晋级标准，仅作为训练目标参考，
/// 实际训练量请根据自身情况在训练页按次调整。
///
/// `_std(bSets, bVal, iSets, iVal, aSets, aVal)` 依次为
/// 初级（组×次数）、中级（组×次数）、高级（组×次数）。
final List<Move> kAllMoves = [
  // ───────────── 俯卧撑 Pushups ─────────────
  _m(e: BigSix.pushup, lv: 1, name: '墙壁俯卧撑', en: 'Wall Pushups',
      cue: '面对墙壁站立，双手撑墙与肩同宽，身体保持一条直线，屈肘让胸口靠近墙面再推回。',
      std: _std(1, 10, 2, 25, 3, 50)),
  _m(e: BigSix.pushup, lv: 2, name: '上斜俯卧撑', en: 'Incline Pushups',
      cue: '双手撑在桌子或台面边缘，身体成一条直线，屈肘让胸口靠近台面再推起。',
      std: _std(1, 10, 2, 20, 3, 40)),
  _m(e: BigSix.pushup, lv: 3, name: '膝盖俯卧撑', en: 'Kneeling Pushups',
      cue: '双膝着地、小腿抬起，双手与肩同宽撑地，身体从膝到肩保持直线。',
      std: _std(1, 10, 2, 15, 3, 30)),
  _m(e: BigSix.pushup, lv: 4, name: '半俯卧撑', en: 'Half Pushups',
      cue: '膝盖离地支撑，只用标准俯卧撑一半的幅度（可用篮球垫在胸下控制高度）。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.pushup, lv: 5, name: '标准俯卧撑', en: 'Full Pushups',
      cue: '双脚并拢，双手与肩同宽，身体成一条直线，下放至胸口几乎贴地。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.pushup, lv: 6, name: '窄距俯卧撑', en: 'Close Pushups',
      cue: '双手拇指与食指相触成菱形，置于胸口正下方，肘部贴近身体。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.pushup, lv: 7, name: '偏重俯卧撑', en: 'Uneven Pushups',
      cue: '一手撑地、一手撑篮球，重心压向撑地一侧，肘部贴身下放。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.pushup, lv: 8, name: '单臂半俯卧撑', en: '1/2 One-Arm Pushups',
      cue: '单手撑地，另一手背在身后，只做一半幅度，核心收紧防止身体旋转。',
      std: _std(1, 5, 2, 8, 2, 12)),
  _m(e: BigSix.pushup, lv: 9, name: '杠杆俯卧撑', en: 'Lever Pushups',
      cue: '单手撑地，另一手撑篮球，随身体下放时球向外滚动，起身时收回。',
      std: _std(1, 5, 2, 8, 2, 12)),
  _m(e: BigSix.pushup, lv: 10, name: '单臂俯卧撑', en: 'One-Arm Pushups',
      cue: '单手撑地，双脚适当分开保持稳定，全程控制完成单臂俯卧撑。',
      std: _std(1, 5, 2, 10, 2, 50)),

  // ───────────── 深蹲 Squats ─────────────
  _m(e: BigSix.squat, lv: 1, name: '肩倒立深蹲', en: 'Shoulderstand Squats',
      cue: '仰卧举腿至肩倒立位，双手扶腰，屈膝下放再伸腿还原。',
      std: _std(1, 10, 2, 25, 3, 50)),
  _m(e: BigSix.squat, lv: 2, name: '折刀深蹲', en: 'Jackknife Squats',
      cue: '手扶膝盖或桌沿，双脚前移，屈膝下蹲至小腿与地面垂直。',
      std: _std(1, 10, 2, 20, 3, 40)),
  _m(e: BigSix.squat, lv: 3, name: '支撑深蹲', en: 'Supported Squats',
      cue: '手扶门框或立柱，下蹲至大腿与地面平行，膝盖不超过脚尖。',
      std: _std(1, 10, 2, 15, 3, 30)),
  _m(e: BigSix.squat, lv: 4, name: '半深蹲', en: 'Half Squats',
      cue: '双脚与肩同宽，双手前伸，下蹲至大腿与地面约成 45 度。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.squat, lv: 5, name: '标准深蹲', en: 'Full Squats',
      cue: '双手前伸，下蹲至大腿与地面平行或略低，脚跟不离地。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.squat, lv: 6, name: '窄距深蹲', en: 'Close Squats',
      cue: '双脚并拢、脚跟相触，保持平衡下蹲至最低点。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.squat, lv: 7, name: '偏重深蹲', en: 'Uneven Squats',
      cue: '一脚踩在篮球或厚书上，重心放在地面那条腿上完成下蹲。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.squat, lv: 8, name: '单腿半深蹲', en: '1/2 One-Leg Squats',
      cue: '一条腿抬起离开地面，只用支撑腿做半程下蹲。',
      std: _std(1, 5, 2, 8, 2, 12)),
  _m(e: BigSix.squat, lv: 9, name: '单腿辅助深蹲', en: 'Assisted One-Leg Squats',
      cue: '单腿下蹲，手扶立柱控制平衡，尽可能减少手臂借力。',
      std: _std(1, 5, 2, 8, 2, 12)),
  _m(e: BigSix.squat, lv: 10, name: '单腿深蹲', en: 'One-Leg Squats',
      cue: '双手前伸保持平衡，单腿下蹲至最低点再起身，另一腿全程悬空。',
      std: _std(1, 5, 2, 10, 2, 20)),

  // ───────────── 引体向上 Pull-ups ─────────────
  _m(e: BigSix.pullup, lv: 1, name: '垂直引体', en: 'Vertical Pulls',
      cue: '面对稳固竖杆或门框站立，双手抓握，身体后倾，用手臂把身体拉向杆。',
      std: _std(1, 10, 2, 20, 3, 40)),
  _m(e: BigSix.pullup, lv: 2, name: '水平引体', en: 'Horizontal Pulls',
      cue: '钻到稳固桌子下方抓住桌沿，身体挺直，把胸口拉向桌面。',
      std: _std(1, 10, 2, 20, 3, 30)),
  _m(e: BigSix.pullup, lv: 3, name: '折刀引体', en: 'Jackknife Pulls',
      cue: '单杠下放椅子，脚踩椅面，身体成折刀形，屈臂把下巴拉向杠。',
      std: _std(1, 10, 2, 15, 3, 20)),
  _m(e: BigSix.pullup, lv: 4, name: '半引体', en: 'Half Pull-ups',
      cue: '正手悬垂，屈臂上拉至一半高度并保持，再缓慢下放。',
      std: _std(1, 5, 2, 10, 2, 15)),
  _m(e: BigSix.pullup, lv: 5, name: '标准引体', en: 'Full Pull-ups',
      cue: '正手与肩同宽握杠，肩胛收紧，拉至下巴过杠再控制下放。',
      std: _std(1, 5, 2, 8, 2, 12)),
  _m(e: BigSix.pullup, lv: 6, name: '窄距引体', en: 'Close Pull-ups',
      cue: '双手间距收窄至约 10~15 厘米，拉起时肘部向前下方走。',
      std: _std(1, 5, 2, 8, 2, 12)),
  _m(e: BigSix.pullup, lv: 7, name: '偏重引体', en: 'Uneven Pull-ups',
      cue: '正手抓杠，另一手抓住该手腕（或垫毛巾），力量更多来自主手。',
      std: _std(1, 5, 2, 8, 2, 10)),
  _m(e: BigSix.pullup, lv: 8, name: '单臂半引体', en: '1/2 One-Arm Pull-ups',
      cue: '单手抓杠悬垂，另一手背在身后，拉至一半高度。',
      std: _std(1, 4, 2, 6, 2, 8)),
  _m(e: BigSix.pullup, lv: 9, name: '单臂辅助引体', en: 'Assisted One-Arm Pull-ups',
      cue: '单手抓杠，另一手在下方轻握该手腕辅助，尽量用主手完成全程。',
      std: _std(1, 3, 2, 5, 2, 7)),
  _m(e: BigSix.pullup, lv: 10, name: '单臂引体', en: 'One-Arm Pull-ups',
      cue: '单手完成完整引体，肩胛先下沉再发力，全程避免摆荡。',
      std: _std(1, 1, 2, 2, 2, 5)),

  // ───────────── 举腿 Leg Raises ─────────────
  _m(e: BigSix.legRaise, lv: 1, name: '坐姿屈膝', en: 'Knee Tucks',
      cue: '坐在椅子边缘，双手扶住椅面，双膝收向胸口再放下。',
      std: _std(1, 10, 2, 20, 3, 40)),
  _m(e: BigSix.legRaise, lv: 2, name: '平躺屈膝抬腿', en: 'Flat Knee Raises',
      cue: '仰卧，双手放于身体两侧，屈膝抬起双腿使臀部离地。',
      std: _std(1, 10, 2, 20, 3, 30)),
  _m(e: BigSix.legRaise, lv: 3, name: '平躺屈腿抬腿', en: 'Flat Bent Leg Raises',
      cue: '仰卧，双腿微屈且并拢，抬起至臀部离地，控制下放。',
      std: _std(1, 10, 2, 15, 3, 25)),
  _m(e: BigSix.legRaise, lv: 4, name: '平躺蛙式抬腿', en: 'Flat Frog Raises',
      cue: '仰卧，双膝外展如青蛙，脚掌相对，上抬骨盆再还原。',
      std: _std(1, 10, 2, 15, 3, 20)),
  _m(e: BigSix.legRaise, lv: 5, name: '平躺直腿抬腿', en: 'Flat Straight Leg Raises',
      cue: '仰卧，双腿伸直并拢，抬至与地面垂直，下放时脚不触地。',
      std: _std(1, 5, 2, 10, 2, 15)),
  _m(e: BigSix.legRaise, lv: 6, name: '悬垂屈膝', en: 'Hanging Knee Raises',
      cue: '悬垂于单杠，双膝收向胸口，避免身体前后摆荡。',
      std: _std(1, 5, 2, 10, 2, 15)),
  _m(e: BigSix.legRaise, lv: 7, name: '悬垂屈腿抬腿', en: 'Hanging Bent Leg Raises',
      cue: '悬垂，双腿微屈，抬起至双腿与地面平行以上。',
      std: _std(1, 5, 2, 10, 2, 15)),
  _m(e: BigSix.legRaise, lv: 8, name: '悬垂蛙式抬腿', en: 'Hanging Frog Raises',
      cue: '悬垂，屈膝外展成蛙形，把膝盖抬向胸口高度。',
      std: _std(1, 5, 2, 10, 2, 15)),
  _m(e: BigSix.legRaise, lv: 9, name: '悬垂半直腿抬腿', en: 'Partial Straight Leg Raises',
      cue: '悬垂，双腿伸直并拢，抬至与地面约成 45~90 度。',
      std: _std(1, 5, 2, 10, 2, 15)),
  _m(e: BigSix.legRaise, lv: 10, name: '悬垂直腿抬腿', en: 'Hanging Straight Leg Raises',
      cue: '悬垂，双腿伸直抬起至脚尖触杠，缓慢下放不摆荡。',
      std: _std(1, 5, 2, 10, 2, 15)),

  // ───────────── 桥 Bridges ─────────────
  _m(e: BigSix.bridge, lv: 1, name: '短桥', en: 'Short Bridges',
      cue: '仰卧屈膝，双脚踩地，手掌下压，抬起臀部并收紧臀肌。',
      std: _std(1, 10, 2, 25, 3, 50)),
  _m(e: BigSix.bridge, lv: 2, name: '直桥', en: 'Straight Bridges',
      cue: '坐姿，双手在身后撑地，抬起臀部使身体从头到脚成一条直线。',
      std: _std(1, 10, 2, 20, 3, 40)),
  _m(e: BigSix.bridge, lv: 3, name: '高低桥', en: 'Angled Bridges',
      cue: '上身靠在床垫或箱子上，双脚踩地，抬起身体成桥。',
      std: _std(1, 10, 2, 15, 3, 30)),
  _m(e: BigSix.bridge, lv: 4, name: '头支撑桥', en: 'Head Bridges',
      cue: '双手与头撑地抬起臀部，用头轻触地面后推起，颈部保持稳定。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.bridge, lv: 5, name: '半桥', en: 'Half Bridges',
      cue: '双手撑地、双肘弯曲，头部离地，身体成拱形。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.bridge, lv: 6, name: '标准桥', en: 'Full Bridges',
      cue: '手脚撑地，手臂基本伸直，头离地，全身成拱形桥。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.bridge, lv: 7, name: '下行桥', en: 'Wall Walking Down',
      cue: '背对墙站立，双手沿墙面逐步下移，直至地面成桥。',
      std: _std(1, 3, 2, 5, 2, 8)),
  _m(e: BigSix.bridge, lv: 8, name: '上行桥', en: 'Wall Walking Up',
      cue: '从桥姿开始，双手沿墙面逐步上移，把身体推回站立。',
      std: _std(1, 3, 2, 5, 2, 8)),
  _m(e: BigSix.bridge, lv: 9, name: '合桥', en: 'Closing Bridges',
      cue: '从桥姿起身时双手离地，仅用腿和脊柱的力量站起。',
      std: _std(1, 3, 2, 5, 2, 8)),
  _m(e: BigSix.bridge, lv: 10, name: '站立拉桥', en: 'Stand-to-Stand Bridges',
      cue: '站立后弯腰下放成桥，再完全不借助手臂站起，全程控制。',
      std: _std(1, 3, 2, 5, 2, 8)),

  // ───────────── 倒立撑 Handstand Pushups ─────────────
  _m(e: BigSix.handstandPushup, lv: 1, name: '折刀俯卧撑', en: 'Jackknife Pushups',
      cue: '俯身屈髋成倒 V 形，双手撑地，头顶朝向地面，屈臂下放再推起。',
      std: _std(1, 10, 2, 15, 3, 30)),
  _m(e: BigSix.handstandPushup, lv: 2, name: '乌鸦式', en: 'Crow Stand',
      cue: '蹲姿双手撑地，膝盖抵住上臂内侧，把双脚离地并保持平衡。',
      metric: MoveMetric.seconds,
      std: _std(1, 10, 2, 20, 3, 30)),
  _m(e: BigSix.handstandPushup, lv: 3, name: '靠墙顶立', en: 'Wall Headstands',
      cue: '面墙或背墙做头倒立，保持身体垂直稳定，颈部不要塌陷。',
      metric: MoveMetric.seconds,
      std: _std(1, 30, 2, 60, 3, 120)),
  _m(e: BigSix.handstandPushup, lv: 4, name: '半倒立撑', en: 'Half Handstand Pushups',
      cue: '靠墙头倒立，屈臂下放头部至离地几厘米处再推起。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.handstandPushup, lv: 5, name: '标准倒立撑', en: 'Handstand Pushups',
      cue: '靠墙倒立，屈臂下放至头部轻触地面，再用肩臂推起。',
      std: _std(1, 5, 2, 10, 2, 20)),
  _m(e: BigSix.handstandPushup, lv: 6, name: '窄距倒立撑', en: 'Close Handstand Pushups',
      cue: '倒立时双手间距收窄至约 10 厘米，下放与推起全程控制。',
      std: _std(1, 5, 2, 8, 2, 15)),
  _m(e: BigSix.handstandPushup, lv: 7, name: '偏重倒立撑', en: 'Uneven Handstand Pushups',
      cue: '倒立时一手撑在砖块或厚书上，重心更多压在另一侧手臂。',
      std: _std(1, 5, 2, 8, 2, 15)),
  _m(e: BigSix.handstandPushup, lv: 8, name: '单臂半倒立撑', en: '1/2 One-Arm Handstand Pushups',
      cue: '单臂撑地倒立，另一手背在身后，只做半程下放。',
      std: _std(1, 4, 2, 6, 2, 8)),
  _m(e: BigSix.handstandPushup, lv: 9, name: '杠杆倒立撑', en: 'Lever Handstand Pushups',
      cue: '单臂撑地，另一手撑在砖块上辅助，逐渐减少辅助手的用力。',
      std: _std(1, 3, 2, 5, 2, 7)),
  _m(e: BigSix.handstandPushup, lv: 10, name: '单臂倒立撑', en: 'One-Arm Handstand Pushups',
      cue: '靠墙单臂倒立撑，核心与肩部全程收紧，控制下降与推起。',
      std: _std(1, 1, 2, 2, 2, 5)),
];

/// 动作库查询。
class MoveCatalog {
  MoveCatalog._();

  static final Map<int, Move> byId = {
    for (final move in kAllMoves) move.id: move,
  };

  /// 按六艺 + 第几式获取动作。
  static Move of(BigSix exercise, int level) =>
      byId[exercise.index * 10 + level]!;

  static Move? byIdOrNull(int id) => byId[id];

  /// 某一艺的十式阶梯（升序）。
  static List<Move> ladder(BigSix exercise) {
    final list = kAllMoves.where((m) => m.exercise == exercise).toList()
      ..sort((a, b) => a.level.compareTo(b.level));
    return list;
  }
}

// ───────────────────────── 构造辅助 ─────────────────────────

Move _m({
  required BigSix e,
  required int lv,
  required String name,
  required String en,
  required String cue,
  MoveMetric metric = MoveMetric.reps,
  required ProgressionStandard std,
}) =>
    Move(
      id: e.index * 10 + lv,
      exercise: e,
      level: lv,
      name: name,
      nameEn: en,
      cue: cue,
      metric: metric,
      standard: std,
    );

ProgressionStandard _std(
  int bSets,
  int bValue,
  int iSets,
  int iValue,
  int aSets,
  int aValue,
) =>
    ProgressionStandard(
      beginner: SetTarget(bSets, bValue),
      intermediate: SetTarget(iSets, iValue),
      advanced: SetTarget(aSets, aValue),
    );
