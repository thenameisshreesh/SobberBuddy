import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Uber-style route animation: the route draws in from origin to destination,
/// a light highlight sweeps along it a few times, then it settles as a solid line.
class RouteAnimation extends ChangeNotifier {
  RouteAnimation({required TickerProvider vsync, required this.color}) {
    _ticker = vsync.createTicker(_onTick);
  }

  final Color color;
  late final Ticker _ticker;

  static const _drawIn = Duration(milliseconds: 900);
  static const _sweep = Duration(milliseconds: 2200);
  // Every update crosses the platform channel to the native map, so the
  // animation must stay short and low-rate or the whole map stutters.
  static const _sweepCount = 3;
  static const _frameInterval = Duration(milliseconds: 42);
  static const _width = 6;

  List<LatLng> _points = const [];
  List<double> _cumulative = const [];
  Set<Polyline> _polylines = const {};
  Polyline? _base;
  Duration _lastFrame = Duration.zero;

  Set<Polyline> get polylines => _polylines;
  List<LatLng> get points => _points;

  Color get _sweepColor => Color.lerp(color, Colors.white, 0.65)!;

  void setRoute(List<LatLng> points) {
    _ticker.stop();
    _points = points.length >= 2 ? List.unmodifiable(points) : const [];
    _cumulative = _cumulativeDistances(_points);
    _base = null;
    _lastFrame = Duration.zero;

    if (_points.isEmpty) {
      _polylines = const {};
      notifyListeners();
      return;
    }
    _render(Duration.zero);
    _ticker.start();
  }

  void clear() => setRoute(const []);

  void _onTick(Duration elapsed) {
    if (elapsed - _lastFrame < _frameInterval) return;
    _lastFrame = elapsed;
    _render(elapsed);
  }

  void _render(Duration elapsed) {
    final sweepElapsed = elapsed - _drawIn;
    if (elapsed < _drawIn) {
      final head = Curves.easeOutCubic
          .transform(elapsed.inMicroseconds / _drawIn.inMicroseconds);
      _polylines = {_line('route_base', _slice(0, head), color, _width, 1)};
    } else if (sweepElapsed >= _sweep * _sweepCount) {
      _ticker.stop();
      _base ??= _line('route_base', _points, color, _width, 1);
      _polylines = {_base!};
    } else {
      _base ??= _line('route_base', _points, color, _width, 1);
      final cycle = (sweepElapsed.inMicroseconds % _sweep.inMicroseconds) /
          _sweep.inMicroseconds;
      final head = Curves.easeInOut.transform(math.min(1.0, cycle / 0.65));
      final tail = Curves.easeInOut.transform(math.max(0.0, (cycle - 0.35) / 0.65));
      _polylines = {
        _base!,
        if (head > tail) _line('route_sweep', _slice(tail, head), _sweepColor, _width, 2),
      };
    }
    notifyListeners();
  }

  Polyline _line(String id, List<LatLng> points, Color color, int width, int zIndex) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: width,
      zIndex: zIndex,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );
  }

  /// Sub-path between fractions [from] and [to] of the route's length.
  List<LatLng> _slice(double from, double to) {
    final total = _cumulative.last;
    if (total <= 0) return _points;
    final start = from * total;
    final end = to * total;

    final result = <LatLng>[_pointAt(start)];
    for (var i = 1; i < _points.length - 1; i++) {
      final distance = _cumulative[i];
      if (distance > start && distance < end) result.add(_points[i]);
    }
    result.add(_pointAt(end));
    return result;
  }

  LatLng _pointAt(double distance) {
    for (var i = 1; i < _points.length; i++) {
      if (_cumulative[i] >= distance) {
        final segment = _cumulative[i] - _cumulative[i - 1];
        final t = segment <= 0 ? 0.0 : (distance - _cumulative[i - 1]) / segment;
        final a = _points[i - 1];
        final b = _points[i];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
    }
    return _points.last;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Smallest bounds containing every point in [points].
LatLngBounds boundsFor(List<LatLng> points) {
  var south = points.first.latitude;
  var north = points.first.latitude;
  var west = points.first.longitude;
  var east = points.first.longitude;
  for (final p in points) {
    south = math.min(south, p.latitude);
    north = math.max(north, p.latitude);
    west = math.min(west, p.longitude);
    east = math.max(east, p.longitude);
  }
  return LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east));
}

List<double> _cumulativeDistances(List<LatLng> points) {
  if (points.isEmpty) return const [];
  final result = <double>[0];
  for (var i = 1; i < points.length; i++) {
    result.add(result.last + _metersBetween(points[i - 1], points[i]));
  }
  return result;
}

double _metersBetween(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) *
          math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

double _rad(double degrees) => degrees * math.pi / 180;
