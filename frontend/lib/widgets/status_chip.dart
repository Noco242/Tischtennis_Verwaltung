// Copyright (c) 2026 Noah, Luca, Sheila, Lando. All rights reserved.

import 'package:flutter/material.dart';

import '../models/spiel.dart';
import '../theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.status,
    this.compact = false,
    super.key,
  });

  final ZusageStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    final icon = _icon(status);
    final label = _label(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  static Color _color(ZusageStatus s) {
    switch (s) {
      case ZusageStatus.zugesagt:
        return AppColors.statusZugesagt;
      case ZusageStatus.abgesagt:
        return AppColors.statusAbgesagt;
      case ZusageStatus.offen:
        return AppColors.statusOffen;
    }
  }

  static IconData _icon(ZusageStatus s) {
    switch (s) {
      case ZusageStatus.zugesagt:
        return Icons.check_circle;
      case ZusageStatus.abgesagt:
        return Icons.cancel;
      case ZusageStatus.offen:
        return Icons.help_outline;
    }
  }

  static String _label(ZusageStatus s) {
    switch (s) {
      case ZusageStatus.zugesagt:
        return 'Zugesagt';
      case ZusageStatus.abgesagt:
        return 'Abgesagt';
      case ZusageStatus.offen:
        return 'Offen';
    }
  }
}
