import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A wrap that stops after a given number of rows and says how many it hid.
///
/// The app header carries a row of flag chips, and an Afrikaans header at 2.0×
/// was measured taking 130dp of a 640dp viewport before anything else drew. The
/// answer is a **cap**: two rows of chips, then a 44dp expander that opens the
/// rest in place. So the header needs to know how many chips did not fit, which
/// is a question only layout can answer.
///
/// It is a real `RenderBox` rather than a `Wrap` in a height-capped box because
/// clipping hides the overflow without counting it, and a count is exactly what
/// the expander's label is. The hidden count is published through
/// [hiddenCount], a [ValueNotifier] the caller listens to — updated after the
/// frame, never during layout, and read by a widget that sits **outside** this
/// one so that a change to the label can never relayout the rows that produced
/// it.
class TorchChipWrap extends MultiChildRenderObjectWidget {
  const TorchChipWrap({
    super.key,
    required List<Widget> chips,
    required this.hiddenCount,
    this.maxRows,
    this.spacing = 12,
    this.runSpacing = 12,
  }) : super(children: chips);

  /// Null shows every row — the expanded state.
  final int? maxRows;

  final double spacing;
  final double runSpacing;

  /// How many chips did not fit. Written after layout.
  final ValueNotifier<int> hiddenCount;

  @override
  RenderTorchChipWrap createRenderObject(BuildContext context) =>
      RenderTorchChipWrap(
        maxRows: maxRows,
        spacing: spacing,
        runSpacing: runSpacing,
        hiddenCount: hiddenCount,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTorchChipWrap renderObject,
  ) {
    renderObject
      ..maxRows = maxRows
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..hiddenCount = hiddenCount;
  }
}

class _ChipParentData extends ContainerBoxParentData<RenderBox> {
  bool visible = true;
}

/// Packs children into rows, left to right, stopping after [maxRows].
class RenderTorchChipWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChipParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChipParentData> {
  RenderTorchChipWrap({
    required int? maxRows,
    required double spacing,
    required double runSpacing,
    required ValueNotifier<int> hiddenCount,
    // ignore: prefer_initializing_formals
  }) : _maxRows = maxRows,
       // ignore: prefer_initializing_formals
       _spacing = spacing,
       // ignore: prefer_initializing_formals
       _runSpacing = runSpacing,
       // ignore: prefer_initializing_formals
       _hiddenCount = hiddenCount;

  int? _maxRows;
  int? get maxRows => _maxRows;
  set maxRows(int? value) {
    if (_maxRows == value) return;
    _maxRows = value;
    markNeedsLayout();
  }

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  ValueNotifier<int> _hiddenCount;
  ValueNotifier<int> get hiddenCount => _hiddenCount;
  set hiddenCount(ValueNotifier<int> value) {
    if (identical(_hiddenCount, value)) return;
    _hiddenCount = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ChipParentData) {
      child.parentData = _ChipParentData();
    }
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth;
    final childConstraints = BoxConstraints(maxWidth: maxWidth);

    var x = 0.0;
    var y = 0.0;
    var rowHeight = 0.0;
    var row = 0;
    var hidden = 0;
    var width = 0.0;

    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ChipParentData;
      child.layout(childConstraints, parentUsesSize: true);
      final size = child.size;

      if (x > 0 && x + spacing + size.width > maxWidth) {
        // This one starts a new row.
        row++;
        if (maxRows != null && row >= maxRows!) {
          // Everything from here on is hidden — including this one.
          data.visible = false;
          hidden++;
          child = data.nextSibling;
          while (child != null) {
            final d = child.parentData! as _ChipParentData;
            d.visible = false;
            // A hidden chip still has to be laid out: an un-laid-out child
            // throws the moment anything asks it a question.
            child.layout(childConstraints, parentUsesSize: true);
            hidden++;
            child = d.nextSibling;
          }
          break;
        }
        y += rowHeight + runSpacing;
        x = 0;
        rowHeight = 0;
      }

      data
        ..visible = true
        ..offset = Offset(x, y);
      x += (x > 0 ? spacing : 0) + size.width;
      if (x > width) width = x;
      if (size.height > rowHeight) rowHeight = size.height;
      child = data.nextSibling;
    }

    size = constraints.constrain(Size(width, y + rowHeight));
    _publish(hidden);
  }

  int _published = -1;

  void _publish(int hidden) {
    if (_published == hidden) return;
    _published = hidden;
    // Never during layout: a notifier that rebuilds a listener mid-layout is
    // the "setState during build" crash with extra steps. The listener lives
    // outside this render object, so the extra frame costs one text repaint.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached) return;
      _hiddenCount.value = hidden;
    });
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) {
    var total = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      total += child.getMaxIntrinsicWidth(height) + spacing;
      child = (child.parentData! as _ChipParentData).nextSibling;
    }
    return total;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ChipParentData;
      if (data.visible) context.paintChild(child, data.offset + offset);
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final data = child.parentData! as _ChipParentData;
      if (data.visible) {
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) =>
              child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // A chip that is not drawn is not announced either — otherwise a screen
    // reader reads eight flags off a header showing three, and the expander
    // that exists to reveal the other five reads as a lie.
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as _ChipParentData;
      if (data.visible) visitor(child);
      child = data.nextSibling;
    }
  }
}
