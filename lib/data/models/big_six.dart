import 'package:flutter/material.dart';

/// 囚徒健身「六艺」：俯卧撑、深蹲、引体向上、举腿、桥、倒立撑。
enum BigSix {
  pushup('俯卧撑', 'Pushups', Icons.accessibility_new),
  squat('深蹲', 'Squats', Icons.airline_seat_legroom_extra),
  pullup('引体向上', 'Pull-ups', Icons.fitness_center),
  legRaise('举腿', 'Leg Raises', Icons.airline_seat_recline_normal),
  bridge('桥', 'Bridges', Icons.landscape_outlined),
  handstandPushup('倒立撑', 'Handstand Pushups', Icons.sports_gymnastics);

  const BigSix(this.label, this.labelEn, this.icon);

  final String label;
  final String labelEn;
  final IconData icon;

  static BigSix fromName(String name) =>
      values.firstWhere((e) => e.name == name, orElse: () => BigSix.pushup);
}
