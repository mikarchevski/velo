import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:gpx/gpx.dart';

class RouteData {
  final List<double> elevations;
  final double totalDistance;
  final String name;
  final List<GeoPoint> points;

  RouteData({
    required this.elevations,
    required this.totalDistance,
    required this.name,
    required this.points,
  });

  RouteData.empty()
      : elevations = [],
        totalDistance = 0.0,
        name = '',
        points = [];

  bool get isEmpty => elevations.isEmpty;
  int get pointCount => elevations.length;
}

class GeoPoint {
  final double lat;
  final double lon;
  final double elevation;

  GeoPoint({required this.lat, required this.lon, required this.elevation});
}

class GpxLoader {
  static RouteData fromString(String gpxString,
      {String name = 'Unknown Route'}) {
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
      geoPoints.add(GeoPoint(
        lat: lat,
        lon: lon,
        elevation: elevation,
      ));

      if (i > 0) {
        final prevPt = points[i - 1];
        final prevLat = prevPt.lat ?? 0.0;
        final prevLon = prevPt.lon ?? 0.0;
        totalDistance += _calculateDistance(lat, lon, prevLat, prevLon);
      }
    }

    return RouteData(
      elevations: elevations,
      totalDistance: totalDistance,
      name: routeName,
      points: geoPoints,
    );
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;

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
}
