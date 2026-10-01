import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:gpx/gpx.dart';

// ==========================================
// 1. Модели данных
// ==========================================

class GeoPoint {
  final double lat;
  final double lon;
  final double elevation;

  GeoPoint({
    required this.lat,
    required this.lon,
    required this.elevation,
  });
}

class RouteData {
  final List<double> elevations;
  final List<double> curves;
  final double totalDistance;
  final String name;
  final List<GeoPoint> points;

  RouteData({
    required this.elevations,
    required this.curves,
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

// ==========================================
// 2. Загрузчик GPX
// ==========================================

class GpxLoader {
  static RouteData fromString(String gpxString, {String name = 'Unknown Route'}) {
    try {
      final gpx = GpxReader().fromString(gpxString);
      return _parseGpx(gpx, name);
    } catch (e) {
      print("❌ Ошибка парсинга GPX из строки: $e");
      return RouteData.empty();
    }
  }

  static Future<RouteData> fromFile(File file) async {
    try {
      final content = await file.readAsString();
      final name = file.uri.pathSegments.last.replaceAll('.gpx', '');
      return fromString(content, name: name);
    } catch (e) {
      print("❌ Ошибка чтения GPX-файла: $e");
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

  // ==========================================
  // 3. Внутренняя логика парсинга
  // ==========================================

  static RouteData _parseGpx(Gpx gpx, String fallbackName) {
    if (gpx.trks.isEmpty) {
      return RouteData.empty();
    }

    final track = gpx.trks.first;
    final routeName = track.name ?? fallbackName;

    if (track.trksegs.isEmpty) {
      return RouteData.empty();
    }

    final points = track.trksegs.first.trkpts;
    final elevations = <double>[];
    final geoPoints = <GeoPoint>[];
    double totalDistance = 0.0;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final elevation = pt.ele ?? 0.0;
      final lat = pt.lat ?? 0.0;
      final lon = pt.lon ?? 0.0;

      elevations.add(elevation);
      geoPoints.add(GeoPoint(lat: lat, lon: lon, elevation: elevation));

      if (i > 0) {
        final prevPt = points[i - 1];
        final prevLat = prevPt.lat ?? 0.0;
        final prevLon = prevPt.lon ?? 0.0;
        totalDistance += _calculateDistance(lat, lon, prevLat, prevLon);
      }
    }

    return RouteData(
      elevations: elevations,
      curves: _calculateCurves(geoPoints),
      totalDistance: totalDistance,
      name: routeName,
      points: geoPoints,
    );
  }

  // Формула гаверсинусов для расчета расстояния между точками
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // в метрах

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  // ==========================================
  // 4. Расчет кривизны (поворотов) трассы
  // ==========================================

  static List<double> _calculateCurves(List<GeoPoint> points) {
    if (points.length < 3) return List.filled(points.length, 0.0);
    
    List<double> bearings = [];
    
    // 1. Вычисляем азимут (направление) между каждой парой точек
    for (int i = 0; i < points.length - 1; i++) {
      double lat1 = points[i].lat * math.pi / 180;
      double lat2 = points[i + 1].lat * math.pi / 180;
      double dLon = (points[i + 1].lon - points[i].lon) * math.pi / 180;
      
      double y = math.sin(dLon) * math.cos(lat2);
      double x = math.cos(lat1) * math.sin(lat2) - 
                 math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
      double bearing = math.atan2(y, x);
      bearings.add(bearing);
    }
    bearings.add(bearings.last); // Дублируем последний элемент для совпадения длины
    
    // 2. Вычисляем разницу азимутов (изменение направления = кривизна)
    List<double> rawCurves = [];
    for (int i = 0; i < bearings.length; i++) {
      if (i == 0) {
        rawCurves.add(0.0);
      } else {
        double diff = bearings[i] - bearings[i - 1];
        // Нормализуем к диапазону [-pi, pi]
        while (diff > math.pi) diff -= 2 * math.pi;
        while (diff < -math.pi) diff += 2 * math.pi;
        rawCurves.add(diff);
      }
    }
    
    // 3. Находим максимальное значение для нормализации
    double maxCurve = rawCurves.fold(0.0, (max, val) => math.max(max, val.abs()));
    if (maxCurve < 0.001) maxCurve = 0.001; // Защита от деления на ноль
    
    // 4. Нормализуем к [-1.0, 1.0] и немного сглаживаем для плавной визуализации
    List<double> smoothedCurves = [];
    for (int i = 0; i < rawCurves.length; i++) {
      double normalized = rawCurves[i] / maxCurve;
      normalized = normalized.clamp(-1.0, 1.0) * 0.8; // 0.8 - коэффициент сглаживания
      smoothedCurves.add(normalized);
    }
    
    return smoothedCurves;
  }
}