import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Takes a gutter-padded child back out to the screen's edges.
///
/// [TorchShell] gutter-pads its children, which is right for almost
/// everything: a block, a rule, a paragraph all hang off the one gutter line.
/// Two things do not — the plate, which is a photograph, and a list of
/// [SoftRow]s, which owns its own gutter and draws its separator rule inset to
/// the text edge. Rather than un-padding the scroll view for everything, those
/// opt out one widget at a time.
///
/// An `OverflowBox` cannot do this job in a `ListView`: it sizes itself to the
/// biggest thing its constraints allow, and a list hands its children an
/// unbounded main axis, so it becomes infinitely tall. Thirty lines of render
/// object is the honest answer — and it reports the child's real height, so
/// the row below lands where the arithmetic says.
class TorchBleed extends SingleChildRenderObjectWidget {
  const TorchBleed({super.key, required super.child, required this.extra});

  /// How much width to give back — the gutter on each side, so `2 × gutter`.
  final double extra;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderTorchBleed(extra);

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
