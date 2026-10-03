import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// ── WHAT THE FRAME SPENT ───────────────────────────────────────────────
///
/// Published by every frame that gutter-pads its scroll view — `TorchShell`
/// on the phone, and each of the desk's panes — and read by [TorchBleed],
/// which gives exactly this much back and never a pixel more.
///
/// ## Why this exists: the caller was guessing, and on a desk it guessed wrong
///
/// `TorchBleed` used to be handed the amount by its caller, and every caller
/// computed the same thing: `skin.space.gutterFor(MediaQuery.sizeOf(context)
/// .width).left * 2` — **the gutter the window would have, not the one the
/// slot actually spent.** On a phone those are the same number and the bug is
/// invisible. In one of the desk's panes they are not:
///
/// | at 1440×900, Orders | measured, before |
/// |---|---|
/// | the list pane's scroll viewport | x = 462 → 1246 (784 wide) |
/// | the `SoftRow` inside it | x = **422 → 1286** (864 wide) |
///
/// 40dp of row outside the viewport on each side, because the pane spends no
/// gutter and the row asked for the window's 40dp back anyway. A viewport
/// clips, so the moment that list is long enough to scroll the right-hand
/// figure is **cut mid-glyph** — which is what the owner photographed at
/// about 2000dp: `R 2,350.7…`, `R 30,723.4…`.
///
/// The cause is not the row, the cap or the pane. It is that the amount was a
/// property of the window and had to be a property of the enclosing slot. So
/// the slot says it, once, and nothing downstream has to agree with anything
/// upstream by arithmetic.
class TorchGutter extends InheritedWidget {
  const TorchGutter({super.key, required this.extent, required super.child});

  /// The horizontal padding the enclosing scroll view spent on **one** side.
  final double extent;

  /// The gutter in force here, or null outside any frame — a sheet, an
  /// overlay, a test that pumps a widget bare.
  static double? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TorchGutter>()
      ?.extent;

  @override
  bool updateShouldNotify(TorchGutter oldWidget) =>
      oldWidget.extent != extent;
}

/// Takes a gutter-padded child back out to the edges of the slot it is in.
///
/// [TorchShell] gutter-pads its children, which is right for almost
/// everything: a block, a rule, a paragraph all hang off the one gutter line.
/// Two things do not — the plate, which is a photograph, and a list of
/// [SoftRow]s, which owns its own gutter and draws its separator rule inset to
/// the text edge. Rather than un-padding the scroll view for everything, those
/// opt out one widget at a time.
///
/// **How much it gives back is not an argument any more.** It is
/// [TorchGutter], published by the frame that spent it — see that class for
/// the defect this replaced. [extra] survives for the one case where there is
/// no frame to ask: a sheet, which pads its own content and is mounted in the
/// navigator's overlay rather than under the shell that opened it.
///
/// An `OverflowBox` cannot do this job in a `ListView`: it sizes itself to the
/// biggest thing its constraints allow, and a list hands its children an
/// unbounded main axis, so it becomes infinitely tall. Thirty lines of render
/// object is the honest answer — and it reports the child's real height, so
/// the row below lands where the arithmetic says.
class TorchBleed extends StatelessWidget {
  const TorchBleed({super.key, required this.child, this.extra});

  final Widget child;

  /// How much width to give back — the gutter on each side, so `2 × gutter`.
  ///
  /// **Null everywhere there is a frame**, which is everywhere but a sheet.
  /// See the class comment.
  final double? extra;

  @override
  Widget build(BuildContext context) {
    final published = TorchGutter.maybeOf(context);
    final resolved = extra ?? (published == null ? null : 2 * published);
    assert(
      resolved != null,
      'TorchBleed has no gutter to give back: there is no TorchGutter above '
      'it and no explicit `extra`. Every frame publishes one; a container '
      'that is not a frame — a sheet, an overlay — passes `extra` instead.',
    );
    return _Bleed(extra: resolved ?? 0, child: child);
  }
}

class _Bleed extends SingleChildRenderObjectWidget {
  const _Bleed({required super.child, required this.extra});

  final double extra;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTorchBleed(extra);

  @override
  void updateRenderObject(BuildContext context, RenderTorchBleed renderObject) {
    renderObject.extra = extra;
  }
}

/// Lays the child out [extra] logical pixels wider than the slot it was given
/// and centres it, so it paints out through the gutter on both sides.
class RenderTorchBleed extends RenderShiftedBox {
  RenderTorchBleed(this._extra) : super(null);

  double _extra;

  set extra(double value) {
    if (value == _extra) return;
    _extra = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final width = constraints.maxWidth + _extra;
    child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    size = constraints.constrain(Size(constraints.maxWidth, child.size.height));
    (child.parentData! as BoxParentData).offset = Offset(-_extra / 2, 0);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width + _extra) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width + _extra) ?? 0;
}
