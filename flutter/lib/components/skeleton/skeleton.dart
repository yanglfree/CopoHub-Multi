import 'package:flutter/material.dart';

/// Common skeleton components.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 4,
    this.color,
  });
  final double? width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0);
    
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF3F3F3F) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final t = _ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final w = bounds.width;
            final h = bounds.height;
            final left = -w * 2.0 + t * w * 3.0;
            return LinearGradient(
              colors: [base, highlight, base],
            ).createShader(Rect.fromLTWH(left, 0, w * 2.0, h));
          },
          child: child,
        );
      },
    );
  }
}
