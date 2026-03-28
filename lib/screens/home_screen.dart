import 'dart:async';
import 'dart:convert';

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
  static const String _openWeatherApiKey =
      '652e2787d0f4daf31caef6a97655ac44';
  static const String _weatherCity = 'London';

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

  bool _weatherLoading = false;
  double? _weatherTempC;
  String? _weatherDescription;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    unawaited(_startSensor());
    unawaited(_fetchWeather());
  }

  @override
  void dispose() {
    unawaited(_luxSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
      'q': _weatherCity,
      'appid': _openWeatherApiKey,
      'units': 'metric',
    });

    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (response.statusCode != 200) {
        var message =
            'Weather request failed (HTTP ${response.statusCode}).';
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          final apiMessage = errBody['message'] as String?;
          if (apiMessage != null && apiMessage.isNotEmpty) {
            message = apiMessage;
          }
        } catch (_) {}
        setState(() {
          _weatherLoading = false;
          _weatherError = message;
          _weatherTempC = null;
          _weatherDescription = null;
        });
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final main = data['main'] as Map<String, dynamic>?;
      final weatherList = data['weather'] as List<dynamic>?;
      Map<String, dynamic>? weather;
      if (weatherList != null && weatherList.isNotEmpty) {
        final first = weatherList.first;
        if (first is Map<String, dynamic>) {
          weather = first;
        }
      }

      if (main == null || weather == null || main['temp'] == null) {
        setState(() {
          _weatherLoading = false;
          _weatherError = 'Could not parse weather data.';
          _weatherTempC = null;
          _weatherDescription = null;
        });
        return;
      }

      final temp = (main['temp'] as num).toDouble();
      final rawDesc = weather['description'] as String? ?? '';

      setState(() {
        _weatherLoading = false;
        _weatherError = null;
        _weatherTempC = temp;
        _weatherDescription = _titleCaseWords(rawDesc);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _weatherError =
            'Could not load weather. Check your connection and try again.';
        _weatherTempC = null;
        _weatherDescription = null;
      });
    }
  }

  String _titleCaseWords(String input) {
    if (input.isEmpty) return input;
    return input
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  Future<void> _startSensor() async {
    setState(() {
      _loading = true;
      _sensorError = null;
    });

    if (!_platformSupportsLight) {
      const mock = 180;
      if (mounted) {
        setState(() {
          _lux = mock;
          _loading = false;
          _sensorError = 'No light sensor available on this platform; using simulated values.';
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
            _sensorError = 'Light sensor is unavailable; using simulated values.';
          });
          _pushSnapshot();
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lux = 150;
        _loading = false;
        _sensorError = 'Unable to read light sensor; using simulated values.';
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
        label: 'Dim',
        advice: 'The light is too dim. Turn on a lamp or move closer to a window to reduce eye strain.',
        accent: AppColors.suggestionDark,
      );
    }
    if (lux < 400) {
      return (
        label: 'Moderate',
        advice: 'The light is comfortable. This environment is suitable for focused study.',
        accent: AppColors.suggestionOk,
      );
    }
    return (
      label: 'Bright',
      advice:
          'The room is bright. Watch out for screen glare and consider lowering your screen brightness.',
      accent: AppColors.suggestionBright,
    );
  }

  Future<void> _onRefresh() async {
    await Future.wait<void>([
      _startSensor(),
      _fetchWeather(),
    ]);
  }

  Widget _buildWeatherBody(ThemeData theme, ColorScheme cs) {
    if (_weatherError != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _weatherError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.error,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
    }

    if (_weatherLoading && _weatherTempC == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_weatherTempC == null || _weatherDescription == null) {
      return Text(
        'No weather data yet.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.wb_cloudy_outlined, color: cs.primary, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_weatherTempC!.toStringAsFixed(1)}°C',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _weatherDescription!,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _weatherCity,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
            tooltip: 'Refresh',
            onPressed: (_loading || _weatherLoading) ? null : _onRefresh,
            icon: (_loading || _weatherLoading)
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
              title: 'Light',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading ? 'Reading...' : '$_lux lx',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status: ${classification.label}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _InfoCard(
              icon: Icons.cloud_outlined,
              title: 'Weather',
              child: _buildWeatherBody(theme, cs),
            ),
            const SizedBox(height: 14),
            _InfoCard(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Study Advice',
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
