import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;

/// Performance monitor overlay for debugging message list performance
///
/// Usage:
/// ```dart
/// PerformanceMonitor(
///   enabled: kDebugMode, // Only show in debug mode
///   child: ConversationDetailView(...),
/// )
/// ```
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final bool showOverlay;

  const PerformanceMonitor({
    Key? key,
    required this.child,
    this.enabled = false,
    this.showOverlay = true,
  }) : super(key: key);

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<Duration> _frameTimes = [];
  int _frameCount = 0;
  Duration _lastFrameTime = Duration.zero;
  double _currentFPS = 60.0;
  int _droppedFrames = 0;
  int _totalFrames = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _ticker = createTicker(_onTick);
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _frameCount++;
      _totalFrames++;

      // Calculate time since last frame
      final frameDuration = elapsed - _lastFrameTime;
      _lastFrameTime = elapsed;

      // Store last 60 frame times (1 second at 60fps)
      _frameTimes.add(frameDuration);
      if (_frameTimes.length > 60) {
        _frameTimes.removeAt(0);
      }

      // Calculate FPS
      if (_frameTimes.isNotEmpty) {
        final avgFrameTime =
            _frameTimes.map((d) => d.inMicroseconds).reduce((a, b) => a + b) ~/
                _frameTimes.length;
        _currentFPS = 1000000 / avgFrameTime;
      }

      // Detect dropped frames (> 16.67ms = < 60fps)
      if (frameDuration.inMilliseconds > 17) {
        _droppedFrames++;
      }

      // Reset counters every second
      if (_frameCount >= 60) {
        _frameCount = 0;
      }
    });
  }

  @override
  void dispose() {
    if (widget.enabled) {
      _ticker.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        if (widget.showOverlay)
          Positioned(
            top: 50,
            right: 10,
            child: _buildPerformanceOverlay(),
          ),
      ],
    );
  }

  Widget _buildPerformanceOverlay() {
    final fpsColor = _currentFPS >= 55
        ? Colors.green
        : _currentFPS >= 45
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fpsColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMetric(
            'FPS',
            _currentFPS.toStringAsFixed(1),
            fpsColor,
          ),
          const SizedBox(height: 4),
          _buildMetric(
            'Dropped',
            '$_droppedFrames / $_totalFrames',
            _droppedFrames > _totalFrames * 0.1 ? Colors.red : Colors.green,
          ),
          const SizedBox(height: 4),
          _buildMetric(
            'Avg Frame',
            '${_frameTimes.isNotEmpty ? (_frameTimes.map((d) => d.inMicroseconds).reduce((a, b) => a + b) ~/ _frameTimes.length / 1000).toStringAsFixed(1) : "0.0"}ms',
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// Widget rebuild counter for debugging
class RebuildCounter extends StatefulWidget {
  final Widget child;
  final String? name;
  final bool enabled;

  const RebuildCounter({
    Key? key,
    required this.child,
    this.name,
    this.enabled = false,
  }) : super(key: key);

  @override
  State<RebuildCounter> createState() => _RebuildCounterState();
}

class _RebuildCounterState extends State<RebuildCounter> {
  int _rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.enabled) {
      _rebuildCount++;
      debugPrint('🔄 ${widget.name ?? 'Widget'} rebuilt $_rebuildCount times');
    }
    return widget.child;
  }
}

/// Performance profiler for measuring widget build times
class PerformanceProfiler {
  static final Map<String, List<int>> _buildTimes = {};
  static final Map<String, int> _buildCounts = {};

  /// Start profiling a widget
  static Stopwatch start(String widgetName) {
    final stopwatch = Stopwatch()..start();
    return stopwatch;
  }

  /// Stop profiling and record the time
  static void stop(String widgetName, Stopwatch stopwatch) {
    stopwatch.stop();
    final microseconds = stopwatch.elapsedMicroseconds;

    _buildTimes.putIfAbsent(widgetName, () => []).add(microseconds);
    _buildCounts[widgetName] = (_buildCounts[widgetName] ?? 0) + 1;

    // Keep only last 100 measurements
    if (_buildTimes[widgetName]!.length > 100) {
      _buildTimes[widgetName]!.removeAt(0);
    }
  }

  /// Get statistics for a widget
  static Map<String, dynamic>? getStats(String widgetName) {
    final times = _buildTimes[widgetName];
    if (times == null || times.isEmpty) return null;

    final avg = times.reduce((a, b) => a + b) ~/ times.length;
    final min = times.reduce((a, b) => a < b ? a : b);
    final max = times.reduce((a, b) => a > b ? a : b);

    return {
      'count': _buildCounts[widgetName],
      'avgMs': (avg / 1000).toStringAsFixed(2),
      'minMs': (min / 1000).toStringAsFixed(2),
      'maxMs': (max / 1000).toStringAsFixed(2),
    };
  }

  /// Get all statistics
  static Map<String, Map<String, dynamic>> getAllStats() {
    final result = <String, Map<String, dynamic>>{};
    for (final widgetName in _buildTimes.keys) {
      final stats = getStats(widgetName);
      if (stats != null) {
        result[widgetName] = stats;
      }
    }
    return result;
  }

  /// Print all statistics to console
  static void printStats() {
    final stats = getAllStats();
    if (stats.isEmpty) {
      debugPrint('⚡ No performance data collected');
      return;
    }

    debugPrint('⚡ Performance Statistics:');
    debugPrint('=' * 60);
    for (final entry in stats.entries) {
      final name = entry.key;
      final data = entry.value;
      debugPrint(
          '$name: ${data['count']} builds, avg ${data['avgMs']}ms (min ${data['minMs']}ms, max ${data['maxMs']}ms)');
    }
    debugPrint('=' * 60);
  }

  /// Reset all statistics
  static void reset() {
    _buildTimes.clear();
    _buildCounts.clear();
  }
}

/// Mixin for automatic performance profiling
mixin ProfiledStateMixin<T extends StatefulWidget> on State<T> {
  late Stopwatch _stopwatch;

  String get widgetName => T.toString();

  @override
  void initState() {
    super.initState();
    _stopwatch = PerformanceProfiler.start(widgetName);
  }

  @override
  Widget build(BuildContext context) {
    final buildStopwatch = PerformanceProfiler.start('$widgetName.build');
    final result = buildWidget(context);
    PerformanceProfiler.stop('$widgetName.build', buildStopwatch);
    return result;
  }

  /// Override this instead of build()
  Widget buildWidget(BuildContext context);

  @override
  void dispose() {
    PerformanceProfiler.stop(widgetName, _stopwatch);
    super.dispose();
  }
}

/// Memory usage tracker
class MemoryTracker {
  static int _lastHeapSize = 0;
  static int _lastRssSize = 0;

  /// Get current memory usage
  static Future<Map<String, dynamic>> getMemoryUsage() async {
    // Note: This requires dart:developer which may not be available in release mode
    try {
      final info = await ui.MemoryAllocations.getMemoryUsage();

      _lastHeapSize = info.heapUsage ?? 0;
      _lastRssSize = info.rssSize ?? 0;

      return {
        'heapMB': (_lastHeapSize / (1024 * 1024)).toStringAsFixed(2),
        'rssMB': (_lastRssSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {
        'heapMB': 'N/A',
        'rssMB': 'N/A',
        'error': e.toString(),
      };
    }
  }

  /// Print memory usage to console
  static Future<void> printMemoryUsage() async {
    final usage = await getMemoryUsage();
    debugPrint('💾 Memory Usage:');
    debugPrint('  Heap: ${usage['heapMB']} MB');
    debugPrint('  RSS: ${usage['rssMB']} MB');
  }
}
