/// Latest environment reading shared between Home and History tabs.
class StudySnapshot {
  const StudySnapshot({
    this.lux = 0,
    this.lightStatus = '未知',
    this.suggestion = '请先在首页刷新以获取环境数据',
  });

  final int lux;
  final String lightStatus;
  final String suggestion;

  StudySnapshot copyWith({
    int? lux,
    String? lightStatus,
    String? suggestion,
  }) {
    return StudySnapshot(
      lux: lux ?? this.lux,
      lightStatus: lightStatus ?? this.lightStatus,
      suggestion: suggestion ?? this.suggestion,
    );
  }
}
