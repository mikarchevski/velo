import 'package:flutter/material.dart';
import 'metric_cards.dart';

class CompactMetric extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;
  final double valueSize;
  final double unitSize;

  const CompactMetric({
    super.key,
    required this.value,
    required this.unit,
    required this.color,
    this.valueSize = 18,
    this.unitSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, maxLines: 1, style: TextStyle(color: color, fontSize: valueSize, fontWeight: FontWeight.bold)),
          ),
          if (unit.isNotEmpty)
            Text(unit, maxLines: 1, style: TextStyle(color: Colors.grey.shade500, fontSize: unitSize)),
        ],
      ),
    );
  }
}

class DataCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color color;
  final bool compact;

  const DataCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 150 : null,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 15, vertical: compact ? 12 : 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: compact ? 12 : 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: color, fontSize: compact ? 34 : 36, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: compact ? 12 : 14)),
        ],
      ),
    );
  }
}