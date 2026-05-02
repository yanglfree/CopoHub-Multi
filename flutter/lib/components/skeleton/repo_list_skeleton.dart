import 'package:flutter/material.dart';

/// 仓库列表骨架屏，用于初次加载时替代 CircularProgressIndicator。
class RepoListSkeleton extends StatelessWidget {
  const RepoListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8),
        itemCount: 7,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (_, __) => const _RepoItemSkeleton(),
      ),
    );
  }
}

class _RepoItemSkeleton extends StatelessWidget {
  const _RepoItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Box(width: 170, height: 14),
          SizedBox(height: 7),
          _Box(height: 12),
          SizedBox(height: 4),
          _Box(width: 210, height: 12),
          SizedBox(height: 11),
          Row(
            children: [
              _Box(width: 11, height: 11, radius: 6),
              SizedBox(width: 5),
              _Box(width: 56, height: 11),
              Spacer(),
              _Box(width: 52, height: 11),
              SizedBox(width: 10),
              _Box(width: 52, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.height, this.width, this.radius = 4});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Shimmer 效果：用一个扫光渐变替换子树中所有不透明像素的颜色。
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
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
    final base =
        isDark ? const Color(0xFF272727) : const Color(0xFFE0E0E0);
    final highlight =
        isDark ? const Color(0xFF3F3F3F) : const Color(0xFFF5F5F5);

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
            // 渐变矩形宽度 = 2W，从 -2W 扫到 +W（总行程 3W）。
            // 高光中心在 t≈0.33~0.67 之间穿越可视区域。
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
