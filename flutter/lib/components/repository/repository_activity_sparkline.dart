import 'package:flutter/material.dart';

import '../../api/github_api_client.dart';
import '../../models/repository_participation.dart';

class RepositoryActivitySparkline extends StatefulWidget {
  const RepositoryActivitySparkline({
    super.key,
    required this.owner,
    required this.repo,
    this.width = 72,
    this.height = 32,
  });

  final String owner;
  final String repo;
  final double width;
  final double height;

  @override
  State<RepositoryActivitySparkline> createState() =>
      _RepositoryActivitySparklineState();
}

class _RepositoryActivitySparklineState
    extends State<RepositoryActivitySparkline> {
  Future<RepositoryParticipation?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant RepositoryActivitySparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner || oldWidget.repo != widget.repo) {
      _future = _load();
    }
  }

  Future<RepositoryParticipation?> _load() async {
    if (widget.owner.isEmpty || widget.repo.isEmpty) return null;
    final result = await GitHubApiClient.instance.getRepositoryParticipation(
      widget.owner,
      widget.repo,
    );
    if (!result.isSuccess) return null;
    return result.data;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<RepositoryParticipation?>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final series = data?.preferredSeries ?? const <int>[];
          if (series.length < 2) return const SizedBox.shrink();

          final cs = Theme.of(context).colorScheme;
          return CustomPaint(
            painter: _SparklinePainter(
              values: series,
              lineColor: data?.hasActivity == true
                  ? const Color(0xFF57AB5A)
                  : cs.outlineVariant,
              baselineColor: cs.outlineVariant.withAlpha(128),
            ),
          );
        },
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.baselineColor,
  });

  final List<int> values;
  final Color lineColor;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    final horizontalStep = size.width / (values.length - 1);
    final verticalPadding = size.height * 0.18;
    final drawableHeight = size.height - verticalPadding * 2;

    final baselineY = size.height - verticalPadding;
    final baselinePaint = Paint()
      ..color = baselineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * horizontalStep;
      final normalized =
          range == 0 ? 0.0 : (values[i] - minValue) / range.toDouble();
      final y = baselineY - normalized * drawableHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.baselineColor != baselineColor;
  }
}
