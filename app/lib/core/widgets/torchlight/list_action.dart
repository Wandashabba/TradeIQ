import 'package:flutter/widgets.dart';

/// ── THE ROUTE'S ONE HEADER CONTROL, LIFTED INTO THE LIST'S TOOLBAR ─────
///
/// > *"the refresh button is in the wrong place … it sits alone at the
/// > top-right corner of the list pane, far from the title and far from
/// > anything it relates to. It reads as a floating artefact."* — the owner,
/// > 4 October 2026, on Beat plans at 1440dp.
///
/// The diagnosis is about **width, not about the header**. `TorchAppHeader`
/// carries at most one trailing icon button and on a phone it lands 48dp from
/// the title, which is where it belongs. The desk puts that same header at the
/// top of the **list pane**, and a list pane at 1440dp is 588dp wide — so the
/// one control ended up 470dp from the words it was attached to, in a corner,
/// with nothing around it. Nothing about the header was wrong; it was simply
/// the wrong row.
///
/// The right row already exists on fifteen of the nineteen desk screens: the
/// section marker that names and counts the records and carries the list's own
/// verb — `PLANS · 50   New plan`. This is how the control gets there.
///
/// ## WHY AN INHERITED WIDGET AND NOT AN ARGUMENT
///
/// Because **the marker is one instance shared by both arms**. Every one of
/// these screens builds its `SectionRule` into a local and hands the same
/// object to the phone's `children` and to the desk's `ConsoleDeskRecords` —
/// `beatplans_screen.dart` says so in as many words ("THE SAME MARKER THE LIST
/// PANE'S `lead` HOLDS, and the same instance"). A marker that took the
/// control as a constructor argument would draw it on the phone too, and the
/// phone is the one thing this change is forbidden to move.
///
/// So the marker declares that it *is* the toolbar row — `SectionRule(…,
/// listAction: true)` — and asks the tree whether there is a control to put on
/// it. Below the desk threshold there is no [TorchListAction] in the tree, the
/// answer is null, and the marker renders the pixels it rendered before this
/// file existed. `desk_phone_identity_test.dart` holds that as a sha256.
///
/// ## WHY THE DESK CANNOT JUST PICK A MARKER ITSELF
///
/// It cannot tell which one. **Three of the fifteen panes hold two
/// `SectionRule`s** and the records' own marker is the second: Sales targets
/// heads the attainment levels with one, Outlets nests one inside
/// `_OpenPinReports`, and Templates nests one inside `_InAudits`. (Dispatch
/// holds two as well and lifts nothing, because its header has no trailing
/// control at all.) "The first marker in the pane" would have put Beat plans'
/// refresh in the right place and Outlets' refresh on the pin-reports block.
///
/// So the screen says which, in one word, and the agreement between the two
/// words is read off the source for all nineteen screens at once rather than
/// pumped nineteen times — `console_desk_test.dart`, *"every
/// ConsoleDeskRecords declares where its controls are"*, which fails a pane
/// that declares nothing, a `marker` pane with no flagged marker or two, and
/// a flag on a pane that would never fire it.
class TorchListAction extends InheritedWidget {
  const TorchListAction({super.key, this.control, required super.child});

  /// The control to draw, or null when this pane has already placed it
  /// somewhere the frame itself owns — the filter rail, on the four screens
  /// that deliberately have no marker.
  ///
  /// Null is therefore **not** "there is nothing to lift": the widget being in
  /// the tree at all is what says the header must not draw its own trailing.
  /// That distinction is the whole reason this is a nullable field on a widget
  /// that is sometimes installed rather than a nullable widget.
  final Widget? control;

  /// Whether the enclosing header's one trailing control has been lifted out
  /// of it. Read by [TorchAppHeader], which then draws nothing in that slot.
  static bool liftedIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TorchListAction>() != null;

  /// The lifted control, for the row that said it is the toolbar. Null below
  /// the desk threshold, and null in a pane that placed it elsewhere.
  static Widget? controlIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TorchListAction>()?.control;

  /// Always, and deliberately. A control is a fresh widget instance on every
  /// build of the frame above, so an identity test here would be `true` in
  /// every case that matters and `false` only in the one case — a pane rebuilt
  /// with a `const` control — where a stale header would be the bug. The
  /// dependents are a header and one marker per pane; there is no third.
  @override
  bool updateShouldNotify(TorchListAction old) => true;
}
