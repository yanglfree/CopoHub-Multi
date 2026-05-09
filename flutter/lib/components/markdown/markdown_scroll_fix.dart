import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wraps a widget (typically [MarkdownBody]) so that vertical drag gestures
/// over horizontally-scrollable children (code blocks, tables rendered by
/// flutter_markdown) are propagated to the nearest vertical ancestor
/// [Scrollable], instead of being silently consumed by the inner horizontal
/// scroll view.
///
/// flutter_markdown wraps every `<pre>` code block and table in a
/// [SingleChildScrollView] with [Axis.horizontal].  These inner scrollables
/// win the gesture arena for any drag — including vertical ones — which
/// prevents the parent [ListView] / [SingleChildScrollView] from receiving
/// vertical scroll events.
///
/// ## Approach
///
/// Uses a raw [Listener] (which does **not** participate in the gesture arena)
/// to observe pointer events.  When a primarily-vertical drag is detected and
/// the parent vertical [Scrollable] is **not** already driving its own drag
/// activity, we create a [ScrollDragController] via [ScrollPosition.drag] and
/// feed it incremental [DragUpdateDetails].  This is the same API that
/// [Scrollable] itself uses internally, so:
///
/// * Scroll physics (clamping, bouncing) are applied correctly.
/// * [NestedScrollView] coordinator state is managed properly.
/// * Momentum / fling animation works (we call [ScrollDragController.end]
///   with the tracked velocity on pointer-up).
///
/// ## Guard: `isScrollingNotifier`
///
/// When the parent vertical scroller already owns the drag (won the gesture
/// arena), its [ScrollPosition.isScrollingNotifier] is `true` and we return
/// immediately.  This prevents double-counting — both the parent's own
/// [DragScrollActivity] and our drag controller would otherwise fight.
///
/// ## Guard: `_skipFirst`
///
/// [Listener.onPointerMove] fires **before** gesture recognizers resolve the
/// arena.  Therefore [isScrollingNotifier] is always `false` on the very first
/// move event.  We skip that first event to give the recognizer one cycle to
/// resolve.  From event 2 onward we know whether the parent won or not.
class MarkdownScrollFix extends StatefulWidget {
  const MarkdownScrollFix({super.key, required this.child});

  final Widget child;

  @override
  State<MarkdownScrollFix> createState() => _MarkdownScrollFixState();
}

class _MarkdownScrollFixState extends State<MarkdownScrollFix> {
  bool _skipFirst = true;

  // Drag state — non-null only when WE are driving the scroll.
  Drag? _drag;
  VelocityTracker? _velocityTracker;
  bool _weOwnDrag = false;

  void _resetDragState() {
    _drag = null;
    _velocityTracker = null;
    _weOwnDrag = false;
    _skipFirst = true;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _skipFirst = true;
        // Cancel any leftover drag from a previous gesture.
        _drag?.cancel();
        _resetDragState();
      },
      onPointerUp: (PointerUpEvent event) {
        if (_drag != null) {
          // Estimate velocity so fling / ballistic animation works.
          final vel = _velocityTracker?.getVelocityEstimate();
          final pixelsPerSecond =
              vel != null ? Offset(0, vel.pixelsPerSecond.dy) : Offset.zero;
          _drag!.end(DragEndDetails(
            velocity: Velocity(pixelsPerSecond: pixelsPerSecond),
          ));
        }
        _resetDragState();
      },
      onPointerCancel: (_) {
        _drag?.cancel();
        _resetDragState();
      },
      onPointerMove: (PointerMoveEvent event) {
        // Skip the very first move event — recognizers have not resolved yet.
        if (_skipFirst) {
          _skipFirst = false;
          return;
        }

        // Only intercept primarily-vertical drags.
        if (event.delta.dy.abs() <= event.delta.dx.abs()) return;

        final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
        if (scrollable == null) return;
        final pos = scrollable.position;

        // If the scrollable already owns the drag (not started by us), let it
        // handle everything — skip to avoid double-counting.
        if (pos.isScrollingNotifier.value && !_weOwnDrag) return;

        // Feed velocity tracker for fling support.
        _velocityTracker ??= VelocityTracker.withKind(event.kind);
        _velocityTracker!.addPosition(event.timeStamp, event.position);

        if (_drag == null) {
          // Begin a new drag activity through the proper ScrollPosition API.
          // For NestedScrollView this goes through the coordinator, keeping
          // inner↔outer state consistent.
          _drag = pos.drag(
            DragStartDetails(globalPosition: event.position),
            () {
              // Dispose callback — the activity was cancelled externally.
              _drag = null;
              _weOwnDrag = false;
            },
          );
          _weOwnDrag = true;
        } else {
          _drag!.update(DragUpdateDetails(
            globalPosition: event.position,
            delta: Offset(0, -event.delta.dy),
            primaryDelta: -event.delta.dy,
          ));
        }
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }
}
