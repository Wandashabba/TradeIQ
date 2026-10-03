import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../features/assistant/answer/composer.dart' show QuestionComposer;
import '../../../l10n/l10n.dart';
import '../../design/motion_budget.dart';
import '../../theme/torchlight/tiq_skin.dart';
import '../nav_destinations.dart';
import 'bleed.dart';
import 'chrome/chrome.dart';
import 'console_wash.dart';
import 'menu_sheet.dart';
import 'section_rule.dart';
import 'state.dart';

/// ── THE CONSOLE AT A DESK — the manager's three panes ───────────────────
///
/// > *"let us make this mobile app a desktop as well, cause managers will be
/// > using the desktop sometimes and agent there's no need for desktop"* —
/// > the owner, and then, picking one of three mockups: *"Lets go with C and
/// > also it should be very seamless and smooth and highest quality product
/// > and UI/UX matching with the mobile app"*.
///
/// ```text
/// ┌────────────┬──────────────┬─────────────────────────┐
/// │  rail      │  list        │  detail                 │
/// │  (nav)     │  (records)   │  (the selected record)  │
/// │            │              │  [ ask bar, this pane ] │
/// └────────────┴──────────────┴─────────────────────────┘
/// ```
///
/// **The agent side gets none of this.** It is phone-only by the same
/// sentence that asked for the console's desk, and nothing in this file is
/// reachable from `TorchShellProfile.agent`.
///
/// ## THE THRESHOLD IS DERIVED, AND THE DERIVATION IS THE WHOLE DESIGN
///
/// `EntryFrame` had already answered this question for the way in:
/// `pageMinWidth` is `readingWidth + 2 × gutterWide` — *the narrowest viewport
/// that holds the column with the wide gutter on both sides* — and there is no
/// second number to keep in step. [deskMinWidth] is the same sentence with
/// three columns in it:
///
/// | term | value | where it comes from |
/// |---|---|---|
/// | `gutterWide` | 40 | the shell's own gutter past 1080dp |
/// | [railWidth] | 244 | the widest destination label, measured — see below |
/// | `blockGap` | 24 | what separates two blocks everywhere else in the product |
/// | [listMinWidth] | 320 | the narrowest record row the product already draws |
/// | 2 × [paneGutter] | 40 | the list pane's own gutter — see [paneGutter] |
/// | `blockGap` | 24 | |
/// | `readingWidth` | 440 | THE MEASURE — the detail pane is one column of prose |
/// | 2 × [paneGutter] | 40 | the detail pane's own gutter |
/// | `gutterWide` | 40 | |
/// | **total** | **1212** | |
///
/// Four of those nine terms are existing tokens, one is the measure, and the
/// two that are new are each the narrowest the product has already approved
/// rather than a new judgement. **1212 is not a round number and is not meant
/// to be**; it is what the arithmetic says, and it moves on its own the day
/// any term in it moves — it has, twice. The rail measured 244 rather than the
/// 232 the first draft estimated, and the threshold went with it; and on 3
/// October 2026 **the panes started spending a gutter of their own**, which
/// took it from 1132 to 1212.
///
/// That second move cost something and it is worth stating: a window between
/// 1132 and 1211 logical pixels used to get the desk and now gets the phone
/// column. No standard laptop viewport lives in that 79dp band — 1280 and
/// 1366 are both above it — and the alternative was panes whose rows are cut
/// at both edges, which is the defect this branch exists to remove. See
/// [paneGutter].
///
/// One consequence is worth reading off: `TiqSpace.gutterFor` switches to
/// `gutterWide` at 1080dp, and 1212 > 1080, so **the desk cannot exist at a
/// width where the shell is still spending its phone gutter.** The derivation
/// is self-consistent rather than approximately so.
///
/// ### The height threshold, and why it is NOT `EntryFrame`'s 900
///
/// `EntryFrame.pageMinHeight` is 900 and its argument is explicit: *a phone in
/// landscape is wide and is still a phone* — 852×393 clears a 520dp width test
/// and must not get the page shape. **That argument does not transfer, because
/// 1212 is not 520.** No phone in any orientation reaches 1212 logical pixels,
/// so the width test alone already excludes every device the 900 was written
/// to exclude.
///
/// Copying 900 anyway would have cost something real and specific: a
/// **1280×800 laptop** — the commonest small desktop viewport there is — fails
/// a 900-tall test and would have been handed the phone column on a 1280dp
/// window. That is the defect `EntryFrame` was written to fix, reintroduced by
/// quoting its constant instead of its method.
///
/// So [deskMinHeight] is derived from what the panes need rather than from
/// what a phone is: the shell's top inset, the header, the gap under it, the
/// **three rows that are the smallest thing which reads as a list**, and the
/// ask bar at the foot of the detail pane with its gaps. 348dp. At 1212dp of
/// width that test discriminates nothing a device produces — it is the floor
/// below which the list pane stops being a list, and it is written down so the
/// next reader does not have to rediscover that the width is doing all the
/// work.
///
/// ## BELOW THE THRESHOLD, NOTHING CHANGES
///
/// [ConsoleFrame] branches once, on [isDesk], and the phone arm is the tree it
/// built before this file existed — the same `TorchShell`, the same children,
/// the same ask bar in the same band. Not a narrower desk: the same widget.
/// `console_desk_test.dart` pumps 390×844 and 360×640 and asserts the phone
/// arm renders no rail and no pane at all.
///
/// ## THE RAIL IS THE MENU SHEET, UN-COLLAPSED — not a second navigation
///
/// `menu_sheet.dart` folded 24 destinations into three group rows because
/// flat they were 2,132dp of content behind a 743dp phone window. **A rail is
/// the viewport that fold was apologising for.** So the rail is the same list,
/// read from the same [managerDestinations], grouped by the same [NavGroup],
/// named by the same [navGroupName], counted by the same
/// `destinationsIn(group).length`, and drawing the same
/// [MenuDestinationRow] — which is now one widget used by two callers rather
/// than a sheet row and a desktop row that somebody has to keep in step.
///
/// What a rail is allowed to drop is the **fold**: with the rows on screen
/// there is nothing to expand, so a group is a marker rather than a control
/// and it is drawn as a [SectionRule] with the count in the marker's own
/// words — `EXECUTION · 9` — which is the grammar the sheet's own comment
/// says that number has.
///
/// **The housekeeping does not come to the rail**, and that is deliberate.
/// The sheet's bottom section — the brightness, the password, the way out — is
/// *not* a destination list, and Sign out is the one irreversible control in
/// the product. It stays exactly where it is, one press of the ask bar's grid
/// key away, which is the whole of why that key is still on the bar at desk
/// width. See [ConsoleDesk] on the grid key.
///
/// **Amber: none.** A rail is navigation and navigation commits nothing. The
/// destination you are standing on is drawn in weight, ink and fill — the
/// sheet's own four channels, none of them a colour — and the census over
/// every desk screen in both skins is unchanged by the rail's presence.
/// `console_desk_amber_test.dart` prints the counts.
class ConsoleDesk {
  const ConsoleDesk._();

  /// The rail's width.
  ///
  /// **Derived from the longest label, measured rather than guessed.** A
  /// destination row is `MenuDestinationRow`: two `indent`s of its enclosing
  /// column (`s5` each), its own `s3` padding on both sides, an 18dp glyph,
  /// `s3` after the glyph, and then the label at `body` 13. That is 94dp of
  /// structure, and `console_desk_test.dart` lays out all 24 labels with a
  /// `TextPainter` in the app's own face and **prints the widest** — the same
  /// method `entry_width_test.dart` uses for [TiqSpace.readingWidth], and for
  /// the same reason: the next type-scale move should fail with the new number
  /// in the failure rather than drift quietly.
  ///
  /// **244, and the first draft said 232.** The measurement is what moved it:
  /// the widest of the 24 is *Perfect Store scorecard* at **148.87dp** in
  /// Schibsted Grotesk at `bodyStrong` 13 — the weight the row you are
  /// standing on wears, so the worst case — and 148.87 + 94 of structure is
  /// 242.87. 232 would have wrapped one destination to two lines on every
  /// desk in the product, and nothing but the test would have said so.
  ///
  /// 244 is 61 × 4, so it is on the base-4 grid like everything else in
  /// [TiqSpace], and it leaves **1.13dp**. That is a check on the derivation,
  /// not the derivation: the next type-scale move fails this test with the new
  /// number in the failure, which is the point of printing it.
  ///
  /// It does not grow with the viewport. A rail is a fixed list of 24 fixed
  /// names; the width that holds the longest of them holds all of them at
  /// 1440dp exactly as it does at 1120, and spending a 1440dp window's extra
  /// pixels on more air around a nav label is spending them on the one pane
  /// that is not the work.
  static const double railWidth = 244;

  /// The list pane's minimum.
  ///
  /// **320 is not a new judgement about how wide a record row should be.** It
  /// is the width this product already draws one at, on the narrowest viewport
  /// it keeps goldens for: 360dp less its two 20dp gutters. Every `SoftRow` in
  /// the console has been approved at that width and is rendered at it in
  /// `test/**/goldens/*_360x640*.png`, so a list pane that never goes below it
  /// is a list pane that never shows a row narrower than one the owner has
  /// already signed off.
  static const double listMinWidth = _narrowestPhone - 2 * TiqSpace.s5;

  /// The narrowest viewport the product keeps goldens for. See [listMinWidth].
  static const double _narrowestPhone = 360;

  /// ── A PANE IS A PHONE COLUMN, AND IT SPENDS A PHONE'S GUTTER ─────────
  ///
  /// The first desk gave its panes no horizontal padding at all, on the
  /// argument that the desk had already spent one gutter outside the rail and
  /// "a gutter inside each pane as well would be three columns of air in a
  /// row". The argument was about air and the consequence was about **ink**:
  /// a `SoftRow` list opts out of its frame's gutter through [TorchBleed], and
  /// with no gutter to opt out of, every row in every pane was laid out 40dp
  /// wider than the viewport that clips it. Measured at 1440×900 on Orders,
  /// before: viewport `x = 462 → 1246`, row `x = 422 → 1286`. The right-hand
  /// figure is cut the moment the list is long enough to scroll.
  ///
  /// So a pane pads itself, and the amount is not a new judgement either —
  /// it is [TiqSpace.gutter], the phone's own 20, for the same reason
  /// [listMinWidth] is 320: **the list pane at its minimum is exactly a 360dp
  /// phone**, 320 of content between two 20dp gutters. Every row in the
  /// product has been approved at that width.
  ///
  /// It is deliberately *not* `gutterWide`. 40 would put [deskMinWidth] at
  /// 1292 and take the desk away from a 1280dp laptop, which is the viewport
  /// [deskMinHeight]'s own note says this layout exists to serve.
  /// `TiqSpace.s5`, which is what both shipping skins set `space.gutter` to.
  /// It is written as the scale step rather than read off a skin because it
  /// has to be a compile-time constant for [deskMinWidth]; `console_desk_test`
  /// asserts the two agree in both skins, so a skin that moved its phone
  /// gutter fails there rather than drawing a pane the bleed overshoots.
  static const double paneGutter = TiqSpace.s5;

  /// The detail pane's width, and it does not grow.
  ///
  /// THE MEASURE plus the pane's own two gutters. It is a fixed width rather
  /// than a share, which is the change that fills the window: the list pane is
  /// [Expanded] against whatever is left, so at 1920 the slack goes into the
  /// records instead of into dead ground beside them.
  ///
  /// The old layout split the remainder 8 : 11 and then capped the record
  /// *inside* the detail pane at [TiqSpace.readingWidth] and centred it, which
  /// produced the second defect the owner named: at 1440 the pane was 618 and
  /// the column inside it 440, so the ask bar at the pane's foot was 618 wide
  /// with a left edge 89dp off the column it belongs to. A pane that is the
  /// column's width cannot disagree with it.
  static double detailWidth(TiqSkin skin) =>
      TiqSpace.readingWidth + 2 * paneGutter;

  /// The narrowest viewport that holds the three panes with the wide gutter on
  /// both sides and a phone's gutter inside each pane. See the class comment's
  /// table.
  ///
  /// At exactly this width the arithmetic closes on itself: the detail pane is
  /// exactly [detailWidth] and the list pane is exactly
  /// `listMinWidth + 2 × paneGutter` — a 360dp phone — with nothing left over.
  static double deskMinWidth(TiqSkin skin) =>
      2 * skin.space.gutterWide +
      railWidth +
      2 * skin.space.blockGap +
      (listMinWidth + 2 * paneGutter) +
      detailWidth(skin);

  /// The shortest viewport in which the list pane is still a list. See the
  /// class comment for why this is derived rather than quoted from
  /// `EntryFrame`.
  static double deskMinHeight(TiqSkin skin) =>
      TiqSpace.s6 + // the console shell's top inset
      TorchAppHeader.minHeightFor(skin) + // the route's title
      TiqSpace.s6 + // the shell's gap under a header
      3 * skin.space.rowMinHeight + // three records, and no fewer
      skin.space.blockGap + // the gap above the bar
      QuestionComposer.barExtent + // the ask bar, in the detail pane
      skin.space.blockGap; // the body's own bottom padding

  /// Whether a viewport of this size gets the desk rather than the phone.
  ///
  /// Exposed so the tests can state the rule rather than rediscover it from
  /// two numbers — `EntryFrame.isPage`'s own reason for existing.
  static bool isDesk(TiqSkin skin, Size size) =>
      size.width >= deskMinWidth(skin) && size.height >= deskMinHeight(skin);

  // THE 8 : 11 SPLIT IS GONE. `listFlex` and `detailFlex` divided the space
  // after the rail in the ratio of the two panes' minimums, which is a
  // proportion rather than a width: at 1920 it handed the detail pane 824dp
  // to draw a 440dp column in and left the difference as ground. The list pane
  // is now `Expanded` against a fixed [detailWidth], so the slack goes into
  // the records. See [detailWidth].
}

/// ── WHAT A ROUTE HANDS THE FRAME TO BECOME THREE PANES ─────────────────
///
/// A screen that is **a list of records** passes one of these; a screen that
/// is not passes nothing and gets the rail with one centred column, which is
/// the right answer for a scorecard, a settings form or a chart dashboard and
/// is also what 23 of the 24 destinations get for free, with no diff at all.
///
/// The frame owns the selection, the panes, the motion and the washes. The
/// screen owns what a record is, which is the one question a shared layout
/// cannot answer for it.
@immutable
class ConsoleDeskRecords {
  const ConsoleDeskRecords({
    required this.records,
    this.filters,
    this.lead = const <Widget>[],
    this.footer,
  });

  /// The screen's records, in the order the list shows them.
  final List<ConsoleDeskRecord> records;

  /// The screen's own filter rail — the identical [TorchFilterRail] the phone
  /// draws, handed over rather than rebuilt.
  ///
  /// **There is no search field, and this slot does not have one**, because
  /// the product does not. The approved mockup draws a search box in the list
  /// pane; a survey of all 24 console destinations found **no text search over
  /// rows anywhere in the app** — the only search input in the console is
  /// inside the timezone picker sheet. Inventing one here would have been a
  /// desktop-only control with no phone counterpart, no component to reuse and
  /// no repository method behind it, which is the opposite of the brief. It is
  /// named as a gap in the PR rather than drawn as a dead box.
  final Widget? filters;

  /// Blocks that belong **above** the list and are not records — Tasks' lead
  /// card, a scorecard, a section marker. They stay in the list pane, because
  /// they are about the list.
  final List<Widget> lead;

  /// The pagination footer, under the records, where the phone puts it.
  final Widget? footer;

  bool get isEmpty => records.isEmpty;
}

/// One record in the list, and what the detail pane shows when it is chosen.
@immutable
class ConsoleDeskRecord {
  const ConsoleDeskRecord({
    required this.id,
    required this.row,
    required this.detail,
  });

  /// Stable across a rebuild and across a refetch, because it is what the
  /// selection is held as. A list index would re-point the detail pane at a
  /// different record the first time the list re-sorted.
  final String id;

  /// The row, exactly as the phone's list draws it. **Not a desktop card** —
  /// it is the screen's own `SoftRow`/`PersonRow`, handed over.
  ///
  /// A builder, and it is handed `selected`, for two reasons that are really
  /// one. The first is that **on the desk the row's tap is the selection**: a
  /// row whose phone `onTap` opens a detail sheet must not also open that
  /// sheet beside a detail pane already showing the same record, so the screen
  /// passes `onTap: null` here and the frame's own gesture takes it. The
  /// second is that building the desk row here leaves the screen's phone
  /// `children` **untouched code** — the arm below the threshold is not a
  /// narrower desk, it is the same lines it was before this file existed.
  final Widget Function(BuildContext context, bool selected) row;

  /// The record at rest, at the detail pane's width.
  ///
  /// A **builder**, not a widget, and that is the whole of why selecting a
  /// record cannot refetch: the frame builds this only for the id that is
  /// selected, on the frame in which it becomes selected, and the providers it
  /// reads are the ones the screen was already watching for the list. Nothing
  /// in this file calls a repository.
  final WidgetBuilder detail;
}

/// ── THE DESK ITSELF ────────────────────────────────────────────────────
///
/// Three panes, or two when the route is not a list. Built by [ConsoleFrame]
/// above [ConsoleDesk.isDesk] and by nothing else.
///
/// ## Why the selection lives ABOVE the breakpoint branch
///
/// > *"it should be very seamless and smooth"*
///
/// The window crossing the threshold must not lose state, and a `State` that
/// sits inside the branch does lose it: the two arms are different widget
/// types, so dragging a window from 1119 to 1121 unmounts one element tree and
/// mounts the other. So the selection is held by [ConsoleDeskScope], which
/// [ConsoleFrame] puts **outside** its `LayoutBuilder` — above the branch, in
/// both arms, mounted at every width. Drag a window narrow and back and the
/// same record is still selected, and the detail pane that comes back has not
/// asked the network anything.
class ConsoleDeskScope extends StatefulWidget {
  const ConsoleDeskScope({super.key, required this.builder});

  final Widget Function(BuildContext context, ConsoleDeskSelection selection)
  builder;

  @override
  State<ConsoleDeskScope> createState() => _ConsoleDeskScopeState();
}

/// The selected record's id, and the one way to change it.
@immutable
class ConsoleDeskSelection {
  const ConsoleDeskSelection({required this.id, required this.select});

  /// A route with no records to select — The Floor, Ask, a scorecard. It is a
  /// const rather than a nullable field on [ConsoleDeskBody] so the pane code
  /// has one shape rather than two.
  static const ConsoleDeskSelection none = ConsoleDeskSelection(
    id: null,
    select: _nothingToSelect,
  );

  static void _nothingToSelect(String _) {}

  /// Null until a record is chosen, and null again when the one that was
  /// chosen leaves the list. See [_ConsoleDeskScopeState.resolve].
  final String? id;

  final ValueChanged<String> select;
}

class _ConsoleDeskScopeState extends State<ConsoleDeskScope> {
  String? _selected;

  /// The selection, reconciled against the records actually in hand.
  ///
  /// A refetch, a filter chip or a sort can take the selected record out of
  /// the list. Holding the id anyway would leave the detail pane showing a
  /// record the list no longer contains — which is worse than showing nothing,
  /// because it is a record the manager can no longer find. So the id is
  /// resolved against the list on every build and falls back to **nothing
  /// selected**, which is a state the detail pane has words for.
  String? resolve(List<ConsoleDeskRecord> records) {
    final id = _selected;
    if (id == null) return null;
    for (final record in records) {
      if (record.id == id) return id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    ConsoleDeskSelection(
      id: _selected,
      select: (id) {
        if (_selected == id) return;
        setState(() => _selected = id);
      },
    ),
  );
}

/// ── THE PANES ──────────────────────────────────────────────────────────
///
/// Built into [TorchShell.desk], which hands it the whole shell minus the
/// safe area with the ground and any ambient wash already under it. It is
/// therefore the one body shape in the product that is **not** a scroll view:
/// each pane scrolls on its own, which is the whole point of panes.
///
/// ## Where the route's header went
///
/// To the top of the **list** pane, because that is what it names. The rail
/// already says where you are — the destination you are standing on is the one
/// drawn in `body.strong`, `ink1` and a `well` — and the detail pane names the
/// record. A title band across all three panes would be a fourth region of
/// chrome saying a third time what two panes already say, on the layout whose
/// brief was that the screen should be the work.
///
/// On a one-column route the header is at the top of that column, which is
/// where `TorchShell` already puts it.
///
/// ## And where the ask bar went
///
/// To the foot of the **detail** pane, which is the mockup the owner approved
/// and is also the only address that is not a lie. The bar's question goes to
/// `/assistant` from every screen — see `ConsoleAskBar` — so it is not *about*
/// the pane it sits in; what it is about is being where the manager's eye
/// already is, which on a three-pane screen is the record they are reading and
/// not the bottom edge of a 1440dp window.
///
/// **The grid key stays on the bar.** The brief allowed that it might be
/// unnecessary once a rail is visible, and for *navigation* it is: every one of
/// the 24 destinations is one click away in the rail. It is kept because the
/// sheet it opens is not only navigation — its bottom section is the
/// brightness, the password and **Sign out**, and the rail deliberately does
/// not carry those (see [ConsoleDesk]). Dropping the key would have left a
/// manager on a desktop with no way to sign out of the app, which is the third
/// capability `menu_sheet.dart` records this project losing to a migration and
/// is not a fourth worth having.
class ConsoleDeskBody extends StatelessWidget {
  const ConsoleDeskBody({
    super.key,
    required this.header,
    required this.askBar,
    required this.children,
    required this.records,
    this.selection = ConsoleDeskSelection.none,
    required this.scrollController,
  });

  /// The route's [TorchAppHeader]. Every route framed here passes one.
  final Widget? header;

  /// The console's one bar, already built by [ConsoleFrame].
  final Widget askBar;

  /// The route's phone body. On a one-column route this is the column; on a
  /// three-pane route it is **not drawn** — [records] replaces it, and the
  /// blocks that are not records come through [ConsoleDeskRecords.lead].
  final List<Widget> children;

  /// Null on a route that is not a list of records.
  final ConsoleDeskRecords? records;

  /// [ConsoleDeskSelection.none] on a route with no records.
  final ConsoleDeskSelection selection;

  final ScrollController? scrollController;

  /// ── A ONE-COLUMN ROUTE FILLS THE WINDOW ──────────────────────────────
  ///
  /// There used to be a cap here — `listMinWidth + blockGap + readingWidth`,
  /// 784 — and the column was centred under it. Measured on Orders, that is
  /// where the owner's second complaint came from:
  ///
  /// | at 2000×1100, before | |
  /// |---|---|
  /// | the content column | x = 742 → 1526 |
  /// | the ask bar beneath it | x = 308 → 1960 |
  /// | ground to the right of the content | **474dp** |
  ///
  /// Two widths, two left edges, and a quarter of the window empty. A pane is
  /// not a page of prose: it is the frame the screen's own blocks lay
  /// themselves out in, exactly as the phone's viewport is, and the phone does
  /// not cap it either. What stays capped is the one thing the cap was written
  /// for — the detail pane, which really is one column of prose, and which is
  /// capped by **being** [ConsoleDesk.detailWidth] rather than by centring
  /// something narrower inside itself.
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final gutter = skin.space.gutterFor(MediaQuery.sizeOf(context).width).left;
    final list = records;

    return Padding(
      // The shell's own console insets, applied once to the whole desk rather
      // than once per pane: the panes are separated by `blockGap`, which is
      // what separates two blocks everywhere else, and a gutter inside each
      // pane as well would be three columns of air in a row.
      padding: EdgeInsets.fromLTRB(
        gutter,
        TiqSpace.s6 + MediaQuery.paddingOf(context).top,
        gutter,
        skin.space.blockGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: ConsoleDesk.railWidth,
            child: ConsoleRail(key: const ValueKey<String>('console-rail')),
          ),
          SizedBox(width: skin.space.blockGap),
          if (list == null)
            // ── RAIL + ONE COLUMN, AND THE COLUMN FILLS ──────────────────
            //
            // A scorecard, a settings form, a chart dashboard or a chat. It
            // gets the rail and nothing else new: no empty third pane, which
            // is a pane whose content is an apology.
            Expanded(
              child: _Pane(
                key: const ValueKey<String>('console-column'),
                foot: askBar,
                scrollController: scrollController,
                children: <Widget>[...?_headerBlock(skin), ...children],
              ),
            )
          else ...<Widget>[
            Expanded(
              child: _Pane(
                key: const ValueKey<String>('console-list'),
                scrollController: scrollController,
                children: <Widget>[
                  ...?_headerBlock(skin),
                  ...list.lead,
                  if (list.filters != null) ...<Widget>[
                    list.filters!,
                    SizedBox(height: skin.space.blockGap),
                  ],
                  for (final record in list.records)
                    _Record(
                      key: ValueKey<String>('console-record-${record.id}'),
                      record: record,
                      selected: selection.id == record.id,
                      onTap: () => selection.select(record.id),
                    ),
                  if (list.footer != null) ...<Widget>[
                    SizedBox(height: skin.space.blockGap),
                    list.footer!,
                  ],
                ],
              ),
            ),
            SizedBox(width: skin.space.blockGap),
            SizedBox(
              // THE MEASURE, AS THE PANE'S OWN WIDTH. See
              // [ConsoleDesk.detailWidth]: a pane that is exactly the column
              // plus its gutters cannot disagree with the bar at its foot
              // about where the column's left edge is.
              width: ConsoleDesk.detailWidth(skin),
              child: _Detail(
                key: const ValueKey<String>('console-detail'),
                records: list,
                selectedId: selection.id,
                askBar: askBar,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget>? _headerBlock(TiqSkin skin) => header == null
      ? null
      : <Widget>[header!, SizedBox(height: skin.space.blockGap)];
}

/// One scrolling pane, optionally with something pinned at its foot.
///
/// The foot is a **sibling** of the scroll view, exactly as `TorchShell.band`
/// is, and for the reason written there: nothing is ever drawn underneath it,
/// so its height is whatever its content measures at 2.0× rather than a token
/// somebody has to keep in step with the type scale.
///
/// ## IT SPENDS A GUTTER, AND IT SAYS SO
///
/// [ConsoleDesk.paneGutter] on both sides of the scroll view, and the same on
/// the foot — so a pane is the phone's own frame at a different width, and
/// everything that opts out of a gutter on the phone opts out of exactly this
/// one here. [TorchGutter] is how a [TorchBleed] inside it finds out; before
/// it existed each caller computed the window's gutter and every row in every
/// pane was laid out 40dp wider than the viewport that clips it.
///
/// ## THE FOOT IS INSIDE THE SAME PADDING AS THE BODY
///
/// > *"the bar runs x=296→1400 while the content column runs x=456→1240"* —
/// > the owner's render, before.
///
/// The foot used to be a sibling of a **capped and centred** body, so the ask
/// bar was the pane's full width and the content was not. Both now hang off
/// one `EdgeInsets`, which is the only arrangement in which they cannot drift:
/// there is no second number to keep in step, because there is no second
/// number.
class _Pane extends StatelessWidget {
  const _Pane({
    super.key,
    required this.children,
    this.foot,
    this.scrollController,
  });

  final List<Widget> children;
  final Widget? foot;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    const gutter = ConsoleDesk.paneGutter;
    return TorchGutter(
      extent: gutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                gutter,
                0,
                gutter,
                foot == null ? 0 : skin.space.blockGap,
              ),
              children: children,
            ),
          ),
          if (foot != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: foot,
            ),
        ],
      ),
    );
  }
}

/// ── THE RAIL: the menu sheet, un-collapsed ─────────────────────────────
///
/// Three group markers and 24 destination rows, from
/// [managerDestinations] — the same list, the same groups, the same names,
/// the same counts and the same row widget the sheet uses. See [ConsoleDesk]
/// for what it drops (the fold, and the housekeeping) and why.
///
/// It scrolls. 27 rows at the 44dp floor is 1,188dp before any gap, which is
/// taller than a 900dp window — the fold existed because that list is long,
/// and a rail does not make it short, it makes it visible.
class ConsoleRail extends StatelessWidget {
  const ConsoleRail({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    // THE SAME QUESTION THE SHEET ASKS, FROM THE SAME FUNCTION. `GoRouter.of`
    // reads an inherited widget the delegate puts above the navigator, so this
    // answers from inside a route; it returns null rather than throwing in a
    // widget test with no router, which is what lets a golden pump the rail
    // with nothing selected.
    final here = menuDestinationFor(currentMenuLocation(context));

    return ListView(
      // No gutter: the desk already spent one, and the rows carry their own
      // indent. The bottom gap is the body's, like every other pane.
      padding: EdgeInsets.only(bottom: skin.space.blockGap),
      children: <Widget>[
        for (final group in NavGroup.values) ...<Widget>[
          // The group's own words and its own number, in the marker's grammar.
          // `menu_sheet.dart` builds the same string for its fold header; both
          // read [menuGroupLabel] so the two cannot drift.
          SectionRule(menuGroupLabel(l10n, group)),
          const SizedBox(height: TiqSpace.s3),
          for (final destination in destinationsIn(group))
            MenuDestinationRow(
              key: ValueKey<String>('rail-${destination.route}'),
              destination: destination,
              here: destination.route == here?.route,
              onTap: () => context.go(destination.route),
            ),
          SizedBox(height: skin.space.blockGap),
        ],
      ],
    );
  }
}

/// One record in the list pane, and the two channels that say it is the one
/// the detail pane is showing.
///
/// ## A RING AND A BED, AND THE FIRST DRAFT WAS A BED ALONE
///
/// This started as `menu_sheet.dart`'s cue for the destination you are
/// standing on — a `well` fill, no outline — and **the render showed it does
/// not transfer.** The sheet's destination rows are flat on the sheet's
/// ground, so a fill behind one is the row. A console record is a `SoftRow`,
/// which is *a card with its own opaque `surface` fill*, so a fill behind it
/// shows only in the card's own margin: on 1440×900 Night the selected row was
/// indistinguishable from its siblings at 1:1 and barely findable at 2×. The
/// cue was there in the widget tree and absent from the screen.
///
/// So the load-bearing channel is the **edge**, which is what `SoftRow`'s own
/// documentation says of its press state in as many words — *"the fill step
/// alone is 1.49:1 … the channel that carries the press on a cheap screen is
/// the edge"*. A 1px `edgeControl` ring at `radii.card`, with the `well` bed
/// kept behind it as the second channel.
///
/// **`edgeControl` and not `edgeStructure`, and that is a measurement.** On
/// the bare Day vignette — the darkest row of the console falloff, and so the
/// worst case — `edgeStructure` is **3.14:1** against a 3.0 floor, 0.14 of
/// margin, the tightest edge number in the skin; `edgeControl` is **4.32:1**,
/// with 1.32. The ring sits on the pane the cool wash lies under, so the
/// margin is what it has to survive, and `console_wash_contrast_test.dart`
/// prints both before and after.
///
/// `lifted` was tried as the bed and rejected by its own token: on Night it is
/// `#262A2F` and reads, and on **Day it is `#2C3B4D`**, a dark navy, which
/// drew a near-black band around a cream card. `well` steps the right way in
/// both skins.
///
/// **Amber: none.** Selection is not a commit.
class _Record extends StatelessWidget {
  const _Record({
    super.key,
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final ConsoleDeskRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final still = MotionBudget.of(context).still;
    final radius = BorderRadius.circular(skin.radii.card);

    // THE ONE THING ON THE DESK THAT MOVES, and it moves on a token.
    //
    // `TiqMotion.press` on `stateCurve`, which is what every other
    // select-and-settle in the product uses — the filter chip, the fold's
    // caret, the row press. A colour tween costs one `drawRRect` per frame and
    // pushes no layer, so it is inside the paint budget: no `saveLayer`, no
    // filter, no shadow.
    //
    // **The detail pane itself does not animate, and that is deliberate.** A
    // cross-fade between two records is an opacity layer, which is a
    // `saveLayer` on the engine and outside the budget — and it is also the
    // thing the brief forbids by name: a pane that fades is a pane that
    // *flashes*. So what transitions is the mark on the row that was chosen,
    // and the pane it points at is simply correct on the next frame.
    // Both channels tween from the same `t`, so the ring and the bed arrive
    // together: an edge that settles before the fill it bounds reads as two
    // objects rather than one row changing state — `_Fold`'s argument for
    // driving its caret and its rows off one controller.
    return Semantics(
      container: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selected ? 1 : 0),
          duration: still
              ? Duration.zero
              : skin.motion.resolve(TiqMotion.press),
          curve: TiqMotion.stateCurve,
          builder: (context, t, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: t == 0 ? null : p.well.withValues(alpha: t),
              borderRadius: radius,
              border: t == 0
                  ? null
                  : Border.all(
                      color: p.edgeControl.withValues(alpha: t),
                      width: skin.depth.borderWidth,
                    ),
            ),
            child: child,
          ),
          child: ConstrainedBox(
            // The kit's own floor, restated on the frame's own box because a
            // record row is a click target here and WCAG 2.5.5 is not a design
            // axis. Every `SoftRow` already clears it; this is the guard for a
            // record whose row is something else.
            constraints: BoxConstraints(minHeight: skin.space.tapTarget),
            child: record.row(context, selected),
          ),
        ),
      ),
    );
  }
}

/// ── THE DETAIL PANE ────────────────────────────────────────────────────
///
/// The selected record at the pane's width, with the ask bar at its foot.
///
/// ## Nothing selected is a state with words, not an empty box
///
/// > *"the things only looking catches are … a detail pane that looks empty
/// > rather than at rest"*
///
/// So the resting pane is an [EmptyState] at [EmptyScope.inPanel] — the same
/// component, the same scope and the same two-part grammar (a headline that
/// names the absence, a sentence that says what is there instead) that every
/// filtered-to-nothing list in the console already uses. No drawing: the
/// assert on `EmptyState` only allows one whole-screen, and a 64dp line
/// drawing in a pane beside a full list would be the pane decorating its own
/// emptiness.
///
/// The sentence does not say "on the left". A pane's address is a layout
/// detail and in RTL it is the wrong one; what the reader needs is the name of
/// the thing to press.
class _Detail extends StatelessWidget {
  const _Detail({
    super.key,
    required this.records,
    required this.selectedId,
    required this.askBar,
  });

  final ConsoleDeskRecords records;
  final String? selectedId;
  final Widget askBar;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    ConsoleDeskRecord? chosen;
    for (final record in records.records) {
      if (record.id == selectedId) chosen = record;
    }

    if (chosen == null) {
      // ── AT REST, AND CENTRED, BECAUSE THAT IS THE DIFFERENCE ───────────
      //
      // > *"a detail pane that looks empty rather than at rest"*
      //
      // Top-aligned in a 900dp pane the same two sentences read as a page that
      // failed to load: a heading in the corner with 700dp of nothing under
      // it. Centred, they read as the pane waiting. Same words, same
      // component, same scope — the only thing that changed is where in the
      // pane they sit, and it is the whole difference between the two
      // renders.
      return TorchGutter(
        extent: ConsoleDesk.paneGutter,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ConsoleDesk.paneGutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: EmptyState(
                    key: const ValueKey<String>('console-detail-at-rest'),
                    scope: EmptyScope.inPanel,
                    headline: records.isEmpty
                        ? 'Nothing to read yet.'
                        : 'No record chosen.',
                    body: records.isEmpty
                        ? 'When this list has something in it, the record you '
                              'choose is read here.'
                        : 'Choose a record from the list and it opens here, '
                              'beside the list you chose it from.',
                  ),
                ),
              ),
              askBar,
            ],
          ),
        ),
      );
    }

    return _Pane(
      foot: askBar,
      // NO CAP INSIDE THE PANE, BECAUSE THE PANE *IS* THE CAP. The record used
      // to be constrained to `readingWidth` and centred in a pane 180dp wider
      // than that, which left the ask bar at the pane's width and the column
      // at the measure — two widths, two left edges. The pane is now
      // `readingWidth + 2 × paneGutter` and the column is what is inside its
      // padding. See [ConsoleDesk.detailWidth].
      children: <Widget>[
        Builder(
          key: ValueKey<String>('console-detail-${chosen.id}'),
          builder: chosen.detail,
        ),
        SizedBox(height: skin.space.blockGap),
      ],
    );
  }
}

/// ── THE DESK FOR A ROUTE THAT CANNOT USE [ConsoleFrame] ────────────────
///
/// > *"Dont be choosy make the app desktop everywhere"* — the owner, 3
/// > October 2026, having opened The Floor and Ask on a desktop and found the
/// > phone column on both.
///
/// Two routes build their own shell and always will. **The Floor** has no app
/// header — the plate is the header — and **Ask** is a transcript with a
/// composer rather than a body with a bar. Neither can hand itself to
/// [ConsoleFrame] without acquiring a title row it has an argument against.
///
/// What they *can* share is the branch, which is the part that was missing:
/// `isDesk`, the shell in its desk slot, the two lights, and
/// [ConsoleDeskBody] with no records. So this is that branch and nothing else
/// — it owns no layout of its own, and [phone] is the tree the route built
/// before this widget existed, called unchanged below the threshold.
class ConsoleDeskBranch extends StatelessWidget {
  const ConsoleDeskBranch({
    super.key,
    required this.bar,
    required this.children,
    required this.phone,
    this.header,
    this.scrollController,
  });

  /// The route's own bar, at the foot of the content column: The Floor's
  /// suggestion chips and composer, Ask's composer. Not [ConsoleAskBar] —
  /// these two routes answer their own questions.
  final Widget bar;

  /// The route's body, in the content column.
  final List<Widget> children;

  /// Null on The Floor, which has no app header and will not grow one. See
  /// `FloorScaffold`.
  final Widget? header;

  final ScrollController? scrollController;

  /// Everything below [ConsoleDesk.deskMinWidth], unchanged.
  final WidgetBuilder phone;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded height is not a tall viewport, it is no viewport —
        // `ConsoleFrame`'s own guard, for its own reason.
        final desk =
            constraints.hasBoundedHeight &&
            ConsoleDesk.isDesk(
              skin,
              Size(constraints.maxWidth, constraints.maxHeight),
            );
        if (!desk) return phone(context);
        return TorchShell(
          profile: TorchShellProfile.console,
          backdrop: consoleDeskWash(skin),
          desk: ConsoleDeskBody(
            header: header,
            askBar: bar,
            records: null,
            scrollController: scrollController,
            children: children,
          ),
          children: const <Widget>[],
        );
      },
    );
  }
}
