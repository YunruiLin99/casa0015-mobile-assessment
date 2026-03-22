import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:light/light.dart';

import '../models/study_snapshot.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onEnvironmentChanged,
  });

  final ValueChanged<StudySnapshot> onEnvironmentChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool get _platformSupportsLight {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  StreamSubscription<int>? _luxSub;
  int _lux = 0;
  bool _loading = true;
  String? _sensorError;

  @override
  void initState() {
    super.initState();
    unawaited(_startSensor());
  }

  @override
  void dispose() {
    unawaited(_luxSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  /// Keeps `http` in use for a future weather API; fails silently offline.
  void _warmHttpStack() {
    http
        .head(Uri.parse('https://flutter.dev'))
        .timeout(const Duration(seconds: 2))
        .catchError((_) => http.Response('', 408));
  }

  Future<void> _startSensor() async {
    setState(() {
      _loading = true;
      _sensorError = null;
    });

    _warmHttpStack();

    if (!_platformSupportsLight) {
      const mock = 180;
      if (mounted) {
        setState(() {
          _lux = mock;
          _loading = false;
          _sensorError = '当前平台无光线传感器，已使用模拟数值';
        });
        _pushSnapshot();
      }
      return;
    }

    await _luxSub?.cancel();
    _luxSub = null;

    try {
      await Light().requestAuthorization();
      _luxSub = Light().lightSensorStream.listen(
        (lux) {
          if (!mounted) return;
          setState(() {
            _lux = lux;
            _loading = false;
            _sensorError = null;
          });
          _pushSnapshot();
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() {
            _lux = 150;
            _loading = false;
            _sensorError = '光线传感器不可用，已使用模拟数值';
          });
          _pushSnapshot();
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lux = 150;
        _loading = false;
        _sensorError = '无法读取光线，已使用模拟数值';
      });
      _pushSnapshot();
    }
  }

  void _pushSnapshot() {
    final c = _classify(_lux);
    widget.onEnvironmentChanged(
      StudySnapshot(
        lux: _lux,
        lightStatus: c.label,
        suggestion: c.advice,
      ),
    );
  }

  ({String label, String advice, Color accent}) _classify(int lux) {
    if (lux < 50) {
      return (
        label: '暗',
        advice: '光线偏暗，建议开灯或靠近窗户，减轻视疲劳。',
        accent: AppColors.suggestionDark,
      );
    }
    if (lux < 400) {
      return (
        label: '适中',
        advice: '光线适中，当前环境较适合专注学习。',
        accent: AppColors.suggestionOk,
      );
    }
    return (
      label: '明亮',
      advice: '环境明亮，注意屏幕反光，可适当调低屏幕亮度。',
      accent: AppColors.suggestionBright,
    );
  }

  Future<void> _onRefresh() async {
    await _startSensor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final classification = _classify(_lux);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StudySync'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _onRefresh,
            icon: _loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_sensorError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: cs.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _sensorError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _InfoCard(
              icon: Icons.wb_sunny_outlined,
              title: '光线状态',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading ? '读取中…' : '$_lux lx',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '状态：${classification.label}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _InfoCard(
              icon: Icons.cloud_outlined,
              title: '天气',
              child: Row(
                children: [
                  Icon(Icons.wb_sunny_rounded, color: Colors.amber.shade700, size: 36),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '18°C',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('晴天', style: theme.textTheme.titleMedium),
                      Text(
                        '（演示数据）',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _InfoCard(
              icon: Icons.lightbulb_outline_rounded,
              title: '学习建议',
              backgroundColor: classification.accent.withValues(alpha: 0.12),
              borderColor: classification.accent.withValues(alpha: 0.35),
              child: Text(
                classification.advice,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.backgroundColor,
    this.borderColor,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: backgroundColor ?? AppColors.cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor ?? cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
