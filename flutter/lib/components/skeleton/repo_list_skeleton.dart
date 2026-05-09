import 'package:flutter/material.dart';
import 'skeleton.dart';

/// 仓库列表骨架屏，用于初次加载时替代 CircularProgressIndicator。
class RepoListSkeleton extends StatelessWidget {
  const RepoListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
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
          SkeletonBox(width: 170, height: 14),
          SizedBox(height: 7),
          SkeletonBox(height: 12),
          SizedBox(height: 4),
          SkeletonBox(width: 210, height: 12),
          SizedBox(height: 11),
          Row(
            children: [
              SkeletonBox(width: 11, height: 11, radius: 6),
              SizedBox(width: 5),
              SkeletonBox(width: 56, height: 11),
              Spacer(),
              SkeletonBox(width: 52, height: 11),
              SizedBox(width: 10),
              SkeletonBox(width: 52, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Trending list skeleton ────────────────────────────────────────────────────

/// 热门仓库列表骨架屏（精选 → 热门项目 / 高频项目 tab）。
class TrendingListSkeleton extends StatelessWidget {
  const TrendingListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8),
        itemCount: 8,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (_, __) => const _TrendingItemSkeleton(),
      ),
    );
  }
}

class _TrendingItemSkeleton extends StatelessWidget {
  const _TrendingItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 32, height: 32, radius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 170, height: 14),
                SizedBox(height: 6),
                SkeletonBox(height: 12),
                SizedBox(height: 4),
                SkeletonBox(width: 220, height: 12),
                SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonBox(width: 11, height: 11, radius: 6),
                    SizedBox(width: 4),
                    SkeletonBox(width: 52, height: 11),
                    SizedBox(width: 12),
                    SkeletonBox(width: 48, height: 11),
                    SizedBox(width: 10),
                    SkeletonBox(width: 40, height: 11),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Curated card skeleton ─────────────────────────────────────────────────────

/// CopoHub精选列表骨架屏（Card 样式）。
class CuratedListSkeleton extends StatelessWidget {
  const CuratedListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => const _CuratedItemSkeleton(),
      ),
    );
  }
}

class _CuratedItemSkeleton extends StatelessWidget {
  const _CuratedItemSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CuratedHeaderSkeleton(),
          const SizedBox(height: 12),
          const SkeletonBox(width: 200, height: 18),
          const SizedBox(height: 8),
          const SkeletonBox(height: 13),
          const SizedBox(height: 4),
          const SkeletonBox(width: 240, height: 13),
          const SizedBox(height: 14),
          Row(
            children: [
              const SkeletonBox(width: 64, height: 12),
              const SizedBox(width: 16),
              const SkeletonBox(width: 56, height: 12),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF272727) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SkeletonBox(width: 48, height: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CuratedHeaderSkeleton extends StatelessWidget {
  const _CuratedHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 160, height: 13),
        Spacer(),
        SkeletonBox(width: 64, height: 12),
      ],
    );
  }
}

// ── Notification list skeleton ────────────────────────────────────────────────

/// 通知列表骨架屏。
class NotificationListSkeleton extends StatelessWidget {
  const NotificationListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 10,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 64, endIndent: 16),
        itemBuilder: (_, __) => const _NotificationItemSkeleton(),
      ),
    );
  }
}

class _NotificationItemSkeleton extends StatelessWidget {
  const _NotificationItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // unread dot placeholder
          Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: SkeletonBox(width: 8, height: 8, radius: 4),
          ),
          // avatar
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: SkeletonBox(width: 36, height: 36, radius: 6),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 11),
                SizedBox(height: 5),
                Row(
                  children: [
                    SkeletonBox(width: 14, height: 14, radius: 4),
                    SizedBox(width: 4),
                    Expanded(child: SkeletonBox(height: 14)),
                  ],
                ),
                SizedBox(height: 4),
                SkeletonBox(width: 220, height: 14),
                SizedBox(height: 6),
                Row(
                  children: [
                    SkeletonBox(width: 56, height: 18, radius: 4),
                    SizedBox(width: 8),
                    SkeletonBox(width: 64, height: 11),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
