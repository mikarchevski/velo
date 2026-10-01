import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:gpx/gpx.dart';

class GeoPoint {
  final double lat;
  final double lon;
  final double elevation;
  GeoPoint({required this.lat, required this.lon, required this.elevation});
}

class RouteData {
  final List<double> elevations;
  final List<double> curves; // 🚀 ДОБАВЛЕНО
  final double totalDistance;
  final String name;
  final List<GeoPoint> points;

  RouteData({
    required this.elevations,
    required this.curves, // 🚀 ДОБАВЛЕНО
    required this.totalDistance,
    required this.name,
    required this.points,
  });

  RouteData.empty()
      : elevations = const [],
        curves = const [],
        totalDistance = 0.0,
        name = 'Unknown',
        points = const [];

  bool get isEmpty => elevations.isEmpty;
  int get pointCount => elevations.length;
}

class GpxLoader {
  static RouteData fromString(String gpxString, {String name = 'Unknown Route'}) {
    try {
      final gpx = GpxReader().fromString(gpxString);
      return _parseGpx(gpx, name);
    } catch (e) {
      print("❌ Ошибка парсинга GPX: $e");
      return RouteData.empty();
    }
  }

  static Future<RouteData> fromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final name = assetPath.split('/').last.replaceAll('.gpx', '');
      return fromString(content, name: name);
    } catch (e) {
      print("❌ Ошибка загрузки GPX из assets: $e");
      return RouteData.empty();
    }
  }

  static RouteData _parseGpx(Gpx gpx, String fallbackName) {
    if (gpx.trks.isEmpty || gpx.trks.first.trksegs.isEmpty) {
      return RouteData.empty();
    }

    final points = gpx.trks.first.trksegs.first.trkpts;
    final elevations = <double>[];
    final geoPoints = <GeoPoint>[];
    double totalDistance = 0.0;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final lat = pt.lat ?? 0.0;
      final lon = pt.lon ?? 0.0;
      final elevation = pt.ele ?? 0.0;

      elevations.add(elevation);
      geoPoints.add(GeoPoint(lat: lat, lon: lon, elevation: elevation));

      if (i > 0) {
        final prevPt = points[i - 1];
        totalDistance += _calculateDistance(lat, lon, prevPt.lat ?? 0.0, prevPt.lon ?? 0.0);
      }
    }

    return RouteData(
      elevations: elevations,
      curves: _calculateCurves(geoPoints), // 🚀 ВЫЧИСЛЯЕМ КРИВИЗНУ
      totalDistance: totalDistance,
      name: gpx.trks.first.name ?? fallbackName,
      points: geoPoints,
    );
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  // 🚀 МЕТОД РАСЧЁТА ПОВОРОТОВ
  static List<double> _calculateCurves(List<GeoPoint> points) {
    if (points.length < 3) return List.filled(points.length, 0.0);
    
    List<double> bearings = [];
    for (int i = 0; i < points.length - 1; i++) {
      double lat1 = points[i].lat * math.pi / 180;
      double lat2 = points[i + 1].lat * math.pi / 180;
      double dLon = (points[i + 1].lon - points[i].lon) * math.pi / 180;
      
      double y = math.sin(dLon) * math.cos(lat2);
      double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
      bearings.add(math.atan2(y, x));
    }
    bearings.add(bearings.last);
    
    List<double> rawCurves = [];
    for (int i = 0; i < bearings.length; i++) {
      if (i == 0) {
        rawCurves.add(0.0);
      } else {
        double diff = bearings[i] - bearings[i - 1];
        while (diff > math.pi) diff -= 2 * math.pi;
        while (diff < -math.pi) diff += 2 * math.pi;
        rawCurves.add(diff);
      }
    }
    
    double maxCurve = rawCurves.fold(0.0, (max, val) => math.max(max, val.abs()));
    if (maxCurve < 0.001) maxCurve = 0.001;
    
    List<double> smoothedCurves = [];
    for (int i = 0; i < rawCurves.length; i++) {
      // Усиливаем коэффициент до 1.5, чтобы повороты были заметны визуально
      double normalized = (rawCurves[i] / maxCurve).clamp(-1.0, 1.0) * 1.5;
      smoothedCurves.add(normalized);
    }
    
    return smoothedCurves;
  }
}