# Featured Tab Layout Optimization — Walkthrough

## Changes Made

### [featured_page.dart](file:///Users/liang/Documents/AI_CODE/CopoHub/flutter/lib/pages/featured/featured_page.dart)

#### 1. Added `_SliverPinnedHeaderDelegate`
A reusable `SliverPersistentHeaderDelegate` for non-collapsing pinned headers with a fixed height.

#### 2. Converted `_GitHubTab` from `StatelessWidget` → `StatefulWidget`
- Now uses `CustomScrollView` + slivers instead of `Column` + `Expanded`
- Absorbed search state from the deleted `_FrequentView` (search controller, visibility toggle, filter logic)
- Added `onRefresh` callback parameter for `RefreshIndicator`

#### 3. Layout structure change

**Before (fixed ~280px headers):**
```
AppBar (56px) — fixed
TopTabBar (44px) — fixed
DatePickerHeader (52px) — fixed in Column
ProBanner (~36px) — fixed in Column
SegmentControl (48px) — fixed in Column
FilterBar (48px) — fixed in child view
Content — remaining space
```

**After (collapsible ~88px):**
```
AppBar (56px) — fixed (Scaffold)
TopTabBar (44px) — fixed (AppBar.bottom)
DatePickerHeader (52px) — SliverToBoxAdapter, scrolls away ✓
ProBanner (~36px) — SliverToBoxAdapter, scrolls away ✓
SegmentControl (48px) — SliverPersistentHeader, pinned ✓
FilterBar (48px) — SliverPersistentHeader, pinned ✓
Content — SliverList / SliverFillRemaining
```

#### 4. Segment-specific sliver builders

| Segment | Method | Filter bar | Content |
|---------|--------|-----------|---------|
| 热门项目 | `_buildTrendingSlivers()` | Pinned: language + 日/周/月 | `SliverList` with dividers |
| 每日报告 | `_buildReportSlivers()` | None | `SliverFillRemaining(hasScrollBody: true)` wrapping `_ReportView` |
| 高频项目 | `_buildFrequentSlivers()` | Pinned: language + search + 累计/最近 | `SliverList` + load-more indicator |

#### 5. Deleted obsolete classes
- `_TrendingView` — logic inlined into `_buildTrendingSlivers()`
- `_FrequentView` / `_FrequentViewState` — logic inlined into `_buildFrequentSlivers()`, search state lifted to `_GitHubTabState`

#### 6. Scroll-to-end auto-load
`NotificationListener<ScrollNotification>` wraps the `CustomScrollView` to trigger auto-load-more when approaching the bottom on the 高频项目 tab.

## Verification

- `flutter analyze` — 0 errors, 0 warnings (66 pre-existing info-level notes in unrelated test files)

## Notes

- The "每日报告" tab uses `SliverFillRemaining(hasScrollBody: true)`, meaning the `DailyReportView` (a `ListView`) fills the remaining space and handles its own internal scrolling. The DatePickerHeader does NOT scroll away for this tab specifically, because the inner scrollable consumes the scroll extent — this is acceptable since the date context is valuable when reading a report.
- `AlwaysScrollableScrollPhysics` is used to ensure pull-to-refresh works even when content doesn't exceed the viewport.
