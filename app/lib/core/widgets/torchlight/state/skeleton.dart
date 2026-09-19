import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';

/// THE LOADING SKELETON — unify §1.11.
///
/// Replaces `CircularProgressIndicator` everywhere. A spinner says "something
/// is happening somewhere"; a skeleton says "a list of four outlets is
/// arriving, and here is where each one will be".
///
/// ## Why Night's blocks are `edgeStructure` and not `well`
///
/// This is the one place the written direction contradicted its own device
/// floor. Night skeleton blocks were `well` #141D27 on `ground` #0B1017 —
/// **1.12:1**, exactly the ratio the foundations call unresolvable — so an
/// agent on 3G watching My work load for four seconds saw a black screen with
/// one sliding line and assumed the app had broken.
///
/// So: a skeleton standing for a **text line** is a solid block filled
/// `edgeStructure` (3.33:1 on the well, 3.73:1 on the ground) at the real
/// line-height and the real measured width. A skeleton standing for a **row**
/// or a **panel** is that object's own 1px `edgeStructure` outline at its real
/// geometry, **empty** — so the page is visibly a list of things arriving and
/// nothing moves when they do.
///
/// Day blocks stay `well` #E2DBCC, which works on paper. Never a shimmer,
/// never a gradient sweep.
///
/// ## The three thresholds
///
/// * **under 600ms** — nothing renders. Most loads finish inside 600ms and a
///   skeleton that flashes is worse than a pause.
/// * **600ms** — the blocks appear.
/// * **still loading** — a single **2px Oatmeal** rule travels the region's
///   top edge on a 1400ms linear loop. Oatmeal (`ink2`), never amber: a
///   skeleton is loading, not live, and an amber pulse on a placeholder tells
///   a manager that a blank is real-time data.
/// * **10s** — the rule stops and a meta line appears with a Retry.
///
/// ## Veld has no skeleton
///
/// A field of grey blocks on white at 40% backlight in the sun is
/// indistinguishable from a broken screen. Veld renders the word `Loading` at
/// `body.strong` on the left gutter, and nothing else.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.label,
    required this.child,
    this.slowLine = 'Still fetching · this is slower than usual',
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  /// What is loading, in the user's words: "outlets", "your work". Read once
  /// by a screen reader as "Loading outlets" — not fourteen empty nodes.
  final String label;

  /// The shells and blocks.
  final Widget child;

  /// Appears with a Retry after [slowAfter].
  final String slowLine;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Nothing renders before this.
  static const Duration appearsAfter = Duration(milliseconds: 600);

  /// The travelling rule stops here and the slow line appears.
  static const Duration slowAfter = Duration(seconds: 10);

  /// The rule's loop. `TiqMotion.skeleton`, restated here so the number is
  /// findable from the component that uses it.
  static const Duration travel = TiqMotion.skeleton;

  /// The rule's thickness.
  static const double ruleThickness = 2;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  // Constructed in `initState`, not lazily in `build`. A ticker created after
  // `didChangeDependencies` makes the vsync mixin resolve `TickerMode` on its
  // way out instead, which is an ancestor lookup on a deactivated element —
  // an assertion at teardown that names neither this widget nor the reason.
  late final AnimationController _controller;
  Timer? _appear;
  Timer? _slow;
  bool _visible = false;
  bool _slowShown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Skeleton.travel);
    _appear = Timer(Skeleton.appearsAfter, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
    _slow = Timer(Skeleton.slowAfter, () {
      if (!mounted) return;
      setState(() => _slowShown = true);
      _controller.stop();
    });
  }

  @override
  void dispose() {
    _appear?.cancel();
    _slow?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // VELD HAS NO SKELETON.
    if (skin.density == TiqDensity.veld) {
      return Semantics(
        label: 'Loading ${widget.label}',
        excludeSemantics: true,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: skin.space.gutter,
              vertical: skin.space.intraBlock,
            ),
            child: Text(
              'Loading',
              style: skin.text.bodyStrong.style(color: skin.palette.ink2),
            ),
          ),
        ),
      );
    }

    if (!_visible) return const SizedBox.shrink();

    final still = MotionBudget.of(context).still;
    final runs = !still && !_slowShown && skin.motion.enabled;
    if (runs && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!runs && _controller.isAnimating) {
      _controller.stop();
    }

    return Semantics(
      // The region carries ONE label. Its blocks are excluded individually, so
      // a reader hears "Loading outlets" rather than eleven empty boxes.
      label: 'Loading ${widget.label}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            children: <Widget>[
              widget.child,
              if (runs)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: Skeleton.ruleThickness,
                  child: _TravellingRule(progress: _controller),
                ),
            ],
          ),
          if (_slowShown) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            Text(
              widget.slowLine,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 2px Oatmeal rule. **Never amber**, by named prohibition.
class _TravellingRule extends StatelessWidget {
  const _TravellingRule({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final runWidth = width * 0.32;
          return AnimatedBuilder(
            animation: progress,
            builder: (context, _) => Stack(
              children: <Widget>[
                Positioned(
                  left: (width + runWidth) * progress.value - runWidth,
                  width: runWidth,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(color: skin.palette.ink2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A block standing for one line of text.
///
/// Sized at the **real** line-height of the role it stands in for and at a
/// fraction of the real measured width, so nothing jumps on arrival.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    required this.role,
    this.widthFactor = 1.0,
    this.width,
  });

  /// The type role whose line this block occupies. Its size × height is the
  /// block's height, and at 2.0× that is scaled by the same scaler the text
  /// would have used.
  final TiqTypeToken role;

  /// A title block at the title's width, a subtitle at 60%, a trailing figure
  /// at the figure's own width.
  final double widthFactor;

  /// An exact width, where the caller knows it — a figure block.
  final double? width;

  /// The block's colour for a skin. Night is `edgeStructure`, not `well`.
  static Color fillFor(TiqSkin skin) => skin.brightness == Brightness.dark
      ? skin.palette.edgeStructure
      : skin.palette.well;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final scaler = MediaQuery.textScalerOf(context);
    final height = scaler.scale(role.size) * role.height;
    final block = SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillFor(skin),
          borderRadius: BorderRadius.circular(skin.radii.chip),
        ),
      ),
    );
    return ExcludeSemantics(
      child: width != null
          ? SizedBox(width: width, child: block)
          : Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widthFactor.clamp(0.0, 1.0),
                child: block,
              ),
            ),
    );
  }
}

/// A row's real outline at its real geometry, empty.
///
/// A list row is flush and rule-separated, so its shell is a rule at the real
/// separator's position; a standalone row is radius-14 and outlined, so its
/// shell is that outline. Both are the object's own edge — never a grey slab
/// where a row will be.
class SkeletonShell extends StatelessWidget {
  const SkeletonShell({
    super.key,
    required this.height,
    this.child,
    this.outlined = false,
  });

  /// The **real** min-height of the thing arriving.
  final double height;

  /// The blocks inside it.
  final Widget? child;

  /// True for a panel or a standalone row (a full outline at radius 14);
  /// false for a list row (a separator rule at its foot).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final edge = skin.palette.edgeStructure;
    final width = skin.depth.borderWidth;
    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        decoration: BoxDecoration(
          borderRadius: outlined
              ? BorderRadius.circular(skin.radii.panel)
              : null,
          border: outlined
              ? Border.all(color: edge, width: width)
              : Border(bottom: BorderSide(color: edge, width: width)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: outlined ? skin.space.gutter : 0,
          vertical: skin.space.intraBlock,
        ),
        child: child,
      ),
    );
  }
}

/// The common shape: a list of [count] rows, each a shell holding a title
/// block and a subtitle block at 60%.
///
/// Three rows and no more when it is a **pagination** skeleton at the foot of
/// a list; a full screen's worth when the list is arriving for the first time.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({
    super.key,
    this.count = 4,
    this.rowHeight,
  });

  final int count;

  /// Defaults to the skin's own row min-height — the real geometry.
  final double? rowHeight;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final height = rowHeight ?? skin.space.rowMinHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          SkeletonShell(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SkeletonLine(role: skin.text.titleM, widthFactor: 0.55),
                const SizedBox(height: TiqSpace.s2),
                SkeletonLine(role: skin.text.meta, widthFactor: 0.35),
              ],
            ),
          ),
      ],
    );
  }
}
