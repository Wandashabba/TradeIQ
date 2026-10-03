/// THE ONE DASHBOARD SCOPE CONTROL — window and territory, for every screen
/// that reads [dashboardFilterProvider].
///
/// This lived inside `dashboard_shell_screen.dart` as a private widget, which
/// is why The Floor — the manager's *home* — shipped with no way to change
/// territory at all. A manager could not ask "how is Gauteng North doing?"
/// without leaving the screen that exists to answer it. That is the fifth
/// capability this project has lost to a migration, and the fix is not a
/// second copy of the control: it is one implementation both screens read.
///
/// Two presentations of the same state, because the two screens have
/// genuinely different room for chrome:
///
/// * [DashboardFilters] — the overview's rail. Five window chips and a
///   territory chip, above everything they scope.
/// * [showDashboardScope] — The Floor's sheet. The same chips and the same
///   territory list, behind the plate's eyebrow, because the reference the
///   owner signed off has no filter chrome on that screen and a toolbar
///   above the photograph would be the boxiest object on it.
///
/// Both write the same [DashboardFilter]. A per-screen filter would let two
/// figures silently disagree about which slice of time they show, which is
/// worse than no control at all.
///
/// ## PROVINCES THAT OPEN — 2 October 2026
///
/// The owner was shown four shapes for this sheet and picked this one: *"Lets
/// ship in this one and also make the font smaller and fit it very nicely"*.
/// Four things moved, and three of them were defects rather than taste.
///
/// **The header was a screen's header on a picker.** `title.l` plus a
/// full-width sentence cost a **measured 100.0dp** from the sheet's own top to
/// the first chip, at both supported widths in both skins — 68dp of it title,
/// gap and sentence, the other 32dp the grabber zone, which stays. It is one
/// line now: the name on the left in `title.m`, the sentence reduced to
/// [AppLocalizations.dashScopeNote] in `meta` on the right. Measured after:
/// **64.0dp**, so **36dp came back**.
///
/// The brief for this change said the header spent ~160px. It did not: 100.0
/// is what `TextPainter` and the real faces produce at 390dp, and that is what
/// was reclaimed from. The bigger saving by far was the list — see [_ScopeRow].
///
/// **Two of the five windows could not be reached.** The chips were a
/// [TorchFilterRail] — a horizontal `ListView` — and at 390dp the fourth chip
/// ("Year to date") was laid out from x=344.3 to x=435.8 and the fifth ("All
/// time") was never built at all. A rail clipped at the right edge with no
/// affordance is a control that hides half its options, and at 360dp it hid
/// the same two. They **wrap** now, so every window is on screen. (The brief
/// named a "Custom" chip as the invisible one. There is no custom range —
/// [DashboardRange] has exactly five members — so the two that were missing
/// are the two named above.)
///
/// **The cards were inset past the label above them.** `SoftRowForm.list`
/// carries a margin of one gutter, so inside a sheet that already pads by one
/// gutter every card's edge sat at 40dp while `TERRITORY` sat at 20dp. The
/// rows hang off **one gutter** now, the same line the eyebrow does.
///
/// **And the list is grouped.** See [groupTerritories] for the rule, which is
/// structural rather than a table of place names: this is multi-tenant and
/// another tenant's territories will not be provinces.
///
/// ## WHY THE SELECTED ROW IS NOT AMBER
///
/// The mockup drew an amber dot on it. The amber census says the sheet paints
/// **zero** lit objects in both skins today — every amber on the route
/// beneath goes out while a sheet is up (unify §1.10) — so one dot would have
/// been 1 against Night's 2 and Day's 1, and would have *fitted the budget*.
/// It is still wrong, for two rules that are categorical rather than
/// arithmetic: unify §1.6 ("selected … is never amber, on any screen, in any
/// skin") and [SoftRow]'s own law that a row never emits light, which
/// `row_amber_test.dart` enforces by counting pixels. So selected wears the
/// chip's vocabulary instead, which costs nothing: `lifted` fill, a tick disc,
/// weight 600 against 400, and ink chosen against the fill. Four channels,
/// three of which survive greyscale — colour is never the only signal.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/torch_press.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../l10n/l10n.dart';
import '../../territories/data/territories_repository.dart';
import '../data/dashboard_repository.dart';

/// The window's own name, localised. `DashboardRange.label` is the wire-ish
/// abbreviation the old pills wore; a fact line and a filter chip are read out
/// loud, so they get words.
String rangeLabel(AppLocalizations l10n, DashboardRange range) =>
    switch (range) {
      DashboardRange.last7 => l10n.dashRangeLast7,
      DashboardRange.last30 => l10n.dashRangeLast30,
      DashboardRange.last90 => l10n.dashRangeLast90,
      DashboardRange.ytd => l10n.dashRangeYtd,
      DashboardRange.allTime => l10n.dashRangeAll,
    };

/// A territory's name from the loaded list, or null when the list has not
/// loaded, failed, or simply does not contain the id — a deleted or stale
/// territory. Never the raw id: a uuid is not a name (unify §1.15).
String? territoryName(WidgetRef ref, String id) => ref
    .watch(territoriesListProvider)
    .maybeWhen(
      data: (list) {
        for (final t in list) {
          if (t.id == id) return t.name;
        }
        return null;
      },
      orElse: () => null,
    );

/// What the territory chip and the plate's eyebrow both say: the chosen
/// territory's name, or "All territories" when nothing is chosen.
///
/// The middle case is the one a screen gets wrong: a territory *is* chosen and
/// the list has not arrived, which is neither "all" nor a name. It says
/// `dashOneTerritory` — "This territory" — because the figures below really
/// are scoped and claiming otherwise is a lie the reader cannot see.
String territoryFact(WidgetRef ref, AppLocalizations l10n, String? id) {
  if (id == null) return l10n.dashAllTerritories;
  return territoryName(ref, id) ?? l10n.dashOneTerritory;
}

/// One filter rail scoping every panel below it — the window and the
/// territory.
///
/// A per-panel control would let two figures silently disagree about which
/// slice of time they show, which is worse than no control at all. Selected is
/// `lifted` + ink-1 border + tick + weight 700 — three channels, never amber,
/// on any screen (unify §1.6).
class DashboardFilters extends ConsumerWidget {
  const DashboardFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(dashboardFilterProvider);
    final territories = ref.watch(territoriesListProvider);

    void update(DashboardFilter next) =>
        ref.read(dashboardFilterProvider.notifier).set(next);

    return TorchFilterRail(
      semanticsLabel: l10n.dashFilters,
      chips: <Widget>[
        for (final range in DashboardRange.values)
          TorchFilterChip(
            key: ValueKey<String>('range-${range.name}'),
            label: rangeLabel(l10n, range),
            selected: range == filter.range,
            onSelected: () => update(filter.copyWith(range: range)),
          ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-territory'),
          // Loading is a state, not a blank: the chip says "All territories"
          // and is not selected, which is exactly what the screen is showing.
          label: territoryFact(ref, l10n, filter.territoryId),
          selected: filter.territoryId != null,
          onSelected: territories.hasValue
              ? () => pickTerritory(context, ref, filter)
              : null,
        ),
      ],
    );
  }
}

/// The sheet's "all" answer. A null pop is a dismissal, so the clear travels
/// as a token — the same reason the old popup menu carried one.
const String allTerritoriesToken = '__all_territories__';

// ── THE GROUPING RULE ─────────────────────────────────────────────────
//
// `Territory.region` is NOT the province. It holds "Inland"/"Coastal" — the
// seed's own comment says so: "`region` keeps the original Inland/Coastal
// convention; the province is in the name" (`backend/scripts/seed/catalog.ts`).
// Grouping by it would file Gauteng North and the Winelands together and split
// the Eastern Cape in half.
//
// So the rule is **structural**, and deliberately not a lookup table of South
// African provinces: this is multi-tenant and another tenant's territories
// will not be provinces. Two structures carry it, and nothing else does:
//
//   1. the **code prefix** before the first hyphen — `GP` from `GP-TSH`;
//   2. the **longest common name prefix** of a group's members, for the group
//      that has no parent territory to be named after.
//
// The thirteen seeded territories give GP (3), WC (2), KZN (2), EC (2) and
// four singletons.

/// The separators a name may hang a qualifier off. The en dash is in this list
/// because the seeded Eastern Cape names use one — `Eastern Cape – Buffalo
/// City` — and a child label that reads "– Buffalo City" is the whole reason
/// this constant is not just a hyphen.
const String _nameSeparators = '-–—·•:;,/|';

bool _isTrimmable(String ch) =>
    ch.trim().isEmpty || _nameSeparators.contains(ch);

String _trimLeadingSeparators(String s) {
  var i = 0;
  while (i < s.length && _isTrimmable(s[i])) {
    i++;
  }
  return s.substring(i);
}

String _trimTrailingSeparators(String s) {
  var end = s.length;
  while (end > 0 && _isTrimmable(s[end - 1])) {
    end--;
  }
  return s.substring(0, end);
}

/// Anything shorter than this is not a name, it is punctuation that survived a
/// strip. Both label rules fall back rather than print it.
const int _shortestUsefulLabel = 2;

/// The part of a territory code before its first hyphen — `GP` from `GP-TSH`,
/// and `GP` from `GP`.
///
/// Only the ASCII hyphen, because that is what a code is made of. The en dash
/// in `Eastern Cape – Buffalo City` is in the *name*; a code is an identifier
/// and identifiers in this product are `[A-Z0-9-]`.
String territoryCodePrefix(String code) {
  final trimmed = code.trim();
  final cut = trimmed.indexOf('-');
  // `< 0`, not `<= 0`: a code that OPENS on a hyphen has an empty prefix
  // rather than being its own whole string. That is what guarantees the
  // invariant the bucket keys rely on — **a prefix is never empty and never
  // contains a hyphen**.
  return cut < 0 ? trimmed : trimmed.substring(0, cut);
}

/// The longest prefix every one of [names] starts with.
String _commonNamePrefix(List<String> names) {
  var prefix = names.first;
  for (final name in names.skip(1)) {
    final limit = math.min(prefix.length, name.length);
    var i = 0;
    while (i < limit && prefix.codeUnitAt(i) == name.codeUnitAt(i)) {
      i++;
    }
    prefix = prefix.substring(0, i);
    if (prefix.isEmpty) break;
  }
  return prefix;
}

/// Whether the common prefix stopped in the middle of a word in any name —
/// "Wester" out of "Westerly". A label cut mid-word is worse than no label.
///
/// **A prefix that ends on a separator ended at a boundary**, whatever comes
/// next. That clause is the one this rule shipped without, and it made the
/// Eastern Cape read `Eastern`: the common prefix is `Eastern Cape – `, the
/// next characters are `N` and `B`, and asking only "is the next character a
/// letter?" called a clean boundary a cut word and backed up over `Cape`. The
/// children then read `Cape – Buffalo City` — exactly the silliness the rule
/// exists to prevent, and found by looking at the rows rather than at the
/// arithmetic.
bool _cutsAWord(String prefix, List<String> names) {
  if (prefix.isEmpty || _isTrimmable(prefix[prefix.length - 1])) return false;
  return names.any(
    (name) => name.length > prefix.length && !_isTrimmable(name[prefix.length]),
  );
}

/// A group's name, derived from its members' names, for the group whose code
/// prefix is nobody's whole code.
///
/// `Eastern Cape – Nelson Mandela Bay` + `Eastern Cape – Buffalo City` gives
/// `Eastern Cape –`, trimmed back of its trailing separator to **Eastern
/// Cape**. Where that yields nothing usable the prefix itself is the label,
/// because `EC` is a worse heading than `Eastern Cape` and a far better one
/// than an empty row.
String territoryGroupLabelFromNames(List<String> names, String fallback) {
  var prefix = _commonNamePrefix(names);
  if (_cutsAWord(prefix, names)) {
    final space = _trimTrailingSeparators(prefix).lastIndexOf(' ');
    prefix = space <= 0 ? '' : prefix.substring(0, space);
  }
  final cleaned = _trimTrailingSeparators(prefix.trim());
  return cleaned.length < _shortestUsefulLabel ? fallback : cleaned;
}

/// A child's label with its group's name taken off the front, so the column
/// does not repeat the same two words down thirteen rows: `Gauteng North
/// (Tshwane)` reads **North (Tshwane)**, `Western Cape Winelands` reads
/// **Winelands**, `Eastern Cape – Buffalo City` reads **Buffalo City**.
///
/// The parent keeps its whole name. Stripping `Gauteng` off `Gauteng` leaves
/// nothing, and a blank row is not a shorter row — so anything that strips to
/// less than [_shortestUsefulLabel] characters is returned whole.
String territoryChildLabel(String groupLabel, String name) {
  if (groupLabel.isEmpty || name.length <= groupLabel.length) return name;
  if (name.substring(0, groupLabel.length).toLowerCase() !=
      groupLabel.toLowerCase()) {
    return name;
  }
  final stripped = _trimLeadingSeparators(name.substring(groupLabel.length));
  return stripped.length < _shortestUsefulLabel ? name : stripped;
}

/// Territories sharing a code prefix — or one territory standing alone.
///
/// **A group of one is not a group.** The mockup drew Free State and Limpopo
/// with an expand chevron and a count of "1"; that is a control that does
/// nothing wearing the clothes of one that does something. [isGroup] is the
/// predicate and the sheet renders a singleton as an ordinary selectable row,
/// with no chevron and no count.
@immutable
class TerritoryGroup {
  const TerritoryGroup({
    required this.key,
    required this.label,
    required this.members,
  });

  /// The code prefix. Stable across rebuilds, which is what the open/closed
  /// state is keyed on.
  final String key;

  /// The heading, which is the parent territory's name where one exists and
  /// [territoryGroupLabelFromNames]' answer where none does.
  final String label;

  /// The parent first where there is one, then the rest by the label they
  /// actually print.
  final List<Territory> members;

  /// Two or more. A group of one renders as a row — see the class note.
  bool get isGroup => members.length > 1;

  bool holds(String? territoryId) =>
      territoryId != null && members.any((t) => t.id == territoryId);
}

/// Group a territory list by code prefix, in the order the list arrived.
///
/// Order is the server's, not alphabetical: the seeded list leads with the
/// three territories a manager asks about most and re-sorting the sheet under
/// them would be a second change nobody asked for. Within a group the parent
/// leads — that is the brief's `Gauteng · East (Ekurhuleni) · North
/// (Tshwane)` — and the rest sort by the label they print, not by the name
/// they were given, because the printed label is what a reader scans.
List<TerritoryGroup> groupTerritories(List<Territory> list) {
  final order = <String>[];
  final buckets = <String, List<Territory>>{};
  for (final territory in list) {
    final prefix = territoryCodePrefix(territory.code);
    // A territory with no usable code shares a prefix with nothing, so it is
    // keyed on its own id — otherwise one unseeded code would collect the
    // whole tenant into a single group called "". The leading hyphen is what
    // makes that key unforgeable, and it is a hyphen rather than a sentinel
    // because the first draft used `\u0000` and the tooling wrote a real NUL
    // byte into the source: Dart compiled it, every test passed, and `grep`
    // and `file` both stopped being able to read the file.
    final key = prefix.isEmpty ? '-${territory.id}' : prefix;
    final bucket = buckets[key];
    if (bucket == null) {
      order.add(key);
      buckets[key] = <Territory>[territory];
    } else {
      bucket.add(territory);
    }
  }

  return <TerritoryGroup>[
    for (final key in order) _groupFor(key, buckets[key]!),
  ];
}

TerritoryGroup _groupFor(String key, List<Territory> members) {
  if (members.length == 1) {
    return TerritoryGroup(
      key: key,
      label: members.single.name,
      members: members,
    );
  }

  // THE HEADER IS NEVER A SELECTION, and this is the line that forces it.
  // `GP`, `WC` and `KZN` each have a territory whose code IS the prefix, so a
  // tappable header could plausibly select it — and `EC` has none, so the same
  // header would do nothing there. A control that selects on three rows and
  // only expands on a fourth is the defect. So the parent is listed as the
  // first CHILD and the header is an expander and nothing else.
  final parentIndex = members.indexWhere((t) => t.code.trim() == key);
  final parent = parentIndex >= 0 ? members[parentIndex] : null;
  final label = parent != null
      ? parent.name
      : territoryGroupLabelFromNames(members.map((t) => t.name).toList(), key);

  // `identical`, not `code != key`: a tenant with two territories carrying the
  // same code would otherwise lose the second one off the list entirely.
  final rest = members.where((t) => !identical(t, parent)).toList()
    ..sort(
      (a, b) => territoryChildLabel(label, a.name).toLowerCase().compareTo(
        territoryChildLabel(label, b.name).toLowerCase(),
      ),
    );

  return TerritoryGroup(
    key: key,
    label: label,
    members: <Territory>[?parent, ...rest],
  );
}

/// The territory list is arbitrary-length, so it is a sheet of rows rather
/// than a `ChoiceRow` — unify §1.10 gives this product one modal container
/// and §18.1 is why a long list opens it.
Future<void> pickTerritory(
  BuildContext context,
  WidgetRef ref,
  DashboardFilter filter,
) async {
  final l10n = context.l10n;
  final chosen = await showTorchSheet<String>(
    context,
    builder: (sheetContext) => TorchSheet(
      semanticsLabel: l10n.dashTerritory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScopeSheetHeader(title: l10n.dashTerritory),
          const SizedBox(height: TiqSpace.s3),
          territoryOptions(context, ref, filter, sheetContext),
        ],
      ),
    ),
  );
  applyTerritory(ref, filter, chosen);
}

/// THE COMPACT HEADER — the name on the left, what the sheet does on the
/// right, on one line.
///
/// It replaces `TorchSheet`'s own `title`/`subtitle` pair on the two scope
/// sheets, and only on them: `title.l` plus a full-width sentence is a
/// screen's header, and this sheet's whole content is a list. The sentence is
/// not deleted, it is shortened to the three words that carry it — the figures
/// below really are scoped by this choice, and a reader who opens a filter
/// sheet has already guessed that.
///
/// The route still has a name: the sheets pass `semanticsLabel`, so
/// `namesRoute` is satisfied without the title being drawn at 20dp.
class ScopeSheetHeader extends StatelessWidget {
  const ScopeSheetHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            // `title.m` (16) rather than the container's `title.l` (20): one
            // step down on the role ladder, taken from the scale rather than
            // from a literal.
            style: skin.text.titleM.style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(width: TiqSpace.s3),
        // `meta` (11), the smallest prose step, in ink-3. A note, not a
        // sentence — and it wraps rather than ellipsing, because Afrikaans is
        // longer and at 2.0× everything here has to give somewhere.
        Flexible(
          child: Text(
            l10n.dashScopeNote,
            style: skin.text.meta.style(color: skin.palette.ink3),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// The rows the territory sheet is made of, so the two-part scope sheet on
/// The Floor can put the window chips above exactly these and not a copy of
/// them.
///
/// "All territories" is the first row and is always present, because clearing
/// a filter has to be as cheap as setting one: a screen that can be scoped and
/// not unscoped is a trap.
Widget territoryOptions(
  BuildContext context,
  WidgetRef ref,
  DashboardFilter filter,
  BuildContext sheetContext,
) {
  final list = ref.read(territoriesListProvider).value ?? const <Territory>[];
  return TerritoryOptions(
    territories: list,
    selectedId: filter.territoryId,
    onChoose: (token) => Navigator.of(sheetContext).pop(token),
  );
}

/// THE GROUPED TERRITORY LIST.
///
/// Stateful for one reason: **which group is open**. It opens on the group
/// holding the current scope, so the sheet comes up with the territory the
/// figures are already scoped to on screen rather than three rows below the
/// fold. With "All territories" chosen there is nothing to reveal and
/// everything is shut.
///
/// One group at a time. Thirteen territories in four groups is a list that
/// fits a 390dp phone shut and does not fit it open, and a sheet whose rows
/// all move when you expand the fourth one is a sheet you lose your place in.
class TerritoryOptions extends StatefulWidget {
  const TerritoryOptions({
    super.key,
    required this.territories,
    required this.selectedId,
    required this.onChoose,
  });

  final List<Territory> territories;

  /// Null is "All territories", which is a choice and not an absence.
  final String? selectedId;

  /// Called with a territory id, or with [allTerritoriesToken] for the clear.
  final ValueChanged<String> onChoose;

  @override
  State<TerritoryOptions> createState() => _TerritoryOptionsState();
}

class _TerritoryOptionsState extends State<TerritoryOptions> {
  List<TerritoryGroup> _groups = const <TerritoryGroup>[];

  /// The open group's [TerritoryGroup.key], or null for all shut.
  String? _open;

  @override
  void initState() {
    super.initState();
    _regroup();
  }

  @override
  void didUpdateWidget(TerritoryOptions old) {
    super.didUpdateWidget(old);
    if (old.territories != widget.territories ||
        old.selectedId != widget.selectedId) {
      _regroup();
    }
  }

  void _regroup() {
    _groups = groupTerritories(widget.territories);
    for (final group in _groups) {
      if (group.isGroup && group.holds(widget.selectedId)) {
        _open = group.key;
        return;
      }
    }
    _open = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = widget.selectedId;

    final rows = <Widget>[
      // THE CLEAR, AND IT IS THE PROMINENT ONE. A `surface` fill at rest, so
      // it stands as an object on the sheet's ground while the list below it
      // is flush — the same pair the chips use, and the reason it reads as
      // "everything" rather than as the first of fourteen options.
      _ScopeRow(
        key: const ValueKey<String>('territory-option-all'),
        label: l10n.dashAllTerritories,
        standing: true,
        strong: true,
        selected: selected == null,
        semanticsLabel: selected == null
            ? '${l10n.dashAllTerritories}. ${l10n.dashSelected}'
            : l10n.dashAllTerritories,
        onTap: () => widget.onChoose(allTerritoriesToken),
      ),
      const SizedBox(height: TiqSpace.s4),
      Eyebrow(l10n.dashTerritory),
      const SizedBox(height: TiqSpace.s2),
    ];

    for (final group in _groups) {
      if (!group.isGroup) {
        rows.add(_territoryRow(group.members.single, group.label));
        continue;
      }
      final open = _open == group.key;
      rows.add(
        _ScopeRow(
          key: ValueKey<String>('territory-group-${group.key}'),
          label: group.label,
          strong: true,
          count: group.members.length,
          expanded: open,
          semanticsLabel: l10n.dashTerritoryGroup(
            group.label,
            group.members.length,
          ),
          onTap: () => setState(() => _open = open ? null : group.key),
        ),
      );
      if (open) {
        for (final member in group.members) {
          rows.add(_territoryRow(member, group.label, indented: true));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _territoryRow(
    Territory territory,
    String groupLabel, {
    bool indented = false,
  }) {
    final l10n = context.l10n;
    // A singleton's group label IS its name, so stripping would leave nothing
    // and `territoryChildLabel` returns the name whole — which is why this one
    // call serves both the grouped children and the ungrouped rows.
    final label = indented
        ? territoryChildLabel(groupLabel, territory.name)
        : territory.name;
    final chosen = territory.id == widget.selectedId;
    return _ScopeRow(
      key: ValueKey<String>('territory-option-${territory.id}'),
      label: label,
      code: territory.code,
      indented: indented,
      selected: chosen,
      // The whole name, never the stripped one: "North (Tshwane)" is a
      // fragment and a screen reader has no column to read it down.
      semanticsLabel: chosen
          ? '${territory.name}. ${l10n.dashSelected}'
          : territory.name,
      onTap: () => widget.onChoose(territory.id),
    );
  }
}

/// ONE ROW IN THE SCOPE SHEET — 44dp, which is the floor and not a choice.
///
/// ## The density, and the number that stopped it
///
/// The rows this replaces were `SoftRow(density: compact)` in the list form:
/// **68dp of card on an 80dp pitch**, measured at both supported widths in
/// both skins with the real faces loaded. They were two lines — `title.m` (16)
/// over the code in `body` — and the code is a six-character identifier, which
/// does not need a line.
///
/// This is one line, and its height is `space.tapTarget` — **44dp**. The
/// content wants less: `body` at 13/1.55 is 20.2dp and `TiqSpace.s2` above and
/// below it makes 36.2. The owner asked for "much smaller" and WCAG 2.5.5 asks
/// for 44, and where those two fight **the floor wins**: the row is padded out
/// to 44 rather than drawn at 36. 44 against an 80dp pitch is 45% off the
/// list, which is where the sheet's fold came from.
///
/// What that bought, measured for all thirteen seeded territories with the
/// sheet opened on each one in turn: at **390×844 every one of them is on
/// screen without a scroll**, and at **360×640 eleven of thirteen** are —
/// Mpumalanga falls past the 88% ceiling by one logical pixel and North West
/// by 45. Before this change the same count at 360×640 was **three** — the
/// ungrouped list put the first territory row at y=324.8 on an 80dp pitch, so
/// the fourth landed at 644.8 of 640, and the old sheet did not open on the
/// current scope at all. (That three is arithmetic off the measured before-
/// geometry rather than a thirteen-case sweep of the old code; the eleven and
/// the thirteen are swept.) The last two are not recoverable without either
/// dropping a window chip off the sheet
/// or putting the rows under the target floor, and both are worse than a
/// scroll; `filter_groups_test.dart` pins the two names so a regression has to
/// say so out loud.
///
/// ## What identifies it
///
/// Nothing, at rest. The list is flush on the sheet's own `ground` with no
/// card, no outline and no rule — thirteen cards inside a sheet is the "very
/// boxy" the owner has twice struck down, and a card's margin is what put the
/// old rows a gutter to the right of their own section label.
///
/// Selected is the chip's vocabulary and never amber (see the library note):
/// `lifted` fill at `radii.control`, a tick disc, weight 600 against 400, and
/// ink picked against the fill rather than against the skin — `lifted` is a
/// dark navy in **both** skins, so Day's `ink1` on it would be dark on dark.
class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    super.key,
    required this.label,
    required this.onTap,
    this.code,
    this.count,
    this.expanded,
    this.selected = false,
    this.standing = false,
    this.strong = false,
    this.indented = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onTap;

  /// The territory's real code, on the right in the figure face. Null on a
  /// group header and on the clear, neither of which has one.
  final String? code;

  /// How many territories a group holds. Null on everything that is not a
  /// group — a count of "1" beside a row that is just a row is the mockup's
  /// own mistake.
  final int? count;

  /// Non-null makes this an **expander and only an expander**: it carries a
  /// chevron, it announces `expanded`, and it never selects. See `_groupFor`.
  final bool? expanded;

  final bool selected;

  /// A `surface` fill at rest — the clear row, which is an object rather than
  /// a line in a list.
  final bool standing;

  /// `body.strong` instead of `body`. The clear and the group headings.
  final bool strong;

  /// A child inside an open group.
  final bool indented;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final isExpander = expanded != null;

    final fill = selected
        ? p.lifted
        : standing
        ? p.surface
        : null;
    // Against the FILL, not against the skin: `lifted` is a dark navy in both
    // skins, so `ink1` on it is dark-on-dark in Day. Same call the chip makes.
    final ink = selected ? torchOnAbyssal(skin) : p.ink1;
    final quietInk = selected ? ink : p.ink3;

    final role = (selected || strong) ? skin.text.bodyStrong : skin.text.body;

    return Semantics(
      button: true,
      selected: isExpander ? null : selected,
      expanded: expanded,
      label: semanticsLabel ?? label,
      // The action, not only the flag: `excludeSemantics` drops the gesture
      // detector's own node, so without `onTap` here this is a control a
      // screen reader can focus and cannot activate.
      onTap: onTap,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onTap,
        borderRadius: BorderRadius.circular(skin.radii.control),
        builder: (context, pressed) => DecoratedBox(
          decoration: BoxDecoration(
            color: pressed ? torchPressSurface(skin).fill : fill,
            borderRadius: BorderRadius.circular(skin.radii.control),
          ),
          child: ConstrainedBox(
            // THE FLOOR. The content measures 36dp; this is what makes the row
            // a target rather than a line of text.
            constraints: BoxConstraints(minHeight: skin.space.tapTarget),
            child: Padding(
              padding: EdgeInsets.only(
                // A child hangs off its group, and the inset is the only thing
                // that says so once the heading has been stripped off its name.
                left: (indented ? TiqSpace.s4 : 0) + TiqSpace.s3,
                right: TiqSpace.s3,
                top: TiqSpace.s2,
                bottom: TiqSpace.s2,
              ),
              child: Row(
                children: <Widget>[
                  // THE TICK, AND NOTHING ELSE LEADS A ROW.
                  //
                  // A collapsed group that holds the current scope briefly
                  // carried a dot here too. Looking at the render killed it:
                  // the dot pushed that one heading 22dp right of its four
                  // siblings, so `Gauteng` hung off a different line from
                  // `Western Cape` and the column stopped being a column. The
                  // signal it carried is redundant anyway — the sheet OPENS on
                  // the group holding the scope, so the only way to see a
                  // collapsed one is to have shut it yourself a tap ago, and
                  // the chip the sheet was opened from still names the
                  // territory. The selected row keeps its tick: it also keeps
                  // a filled block, so there the inset reads as emphasis
                  // rather than as a row that failed to line up.
                  if (selected) ...<Widget>[
                    TiqMark(
                      shape: MarkShape.sectionTickDisc,
                      color: ink,
                      ground: fill ?? p.ground,
                      size: MarkScale.glyph(context, 14),
                    ),
                    const SizedBox(width: TiqSpace.s2),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: role.style(color: ink),
                      // Two lines, then it gives up. A truncated territory is
                      // a territory you cannot identify, and at 2.0× the row
                      // grows rather than the name shrinking.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (code != null) ...<Widget>[
                    const SizedBox(width: TiqSpace.s2),
                    Text(
                      code!,
                      // `mono.ident` — the identifier role, which is what a
                      // territory code is, and the same role
                      // `territories_screen.dart` already prints this exact
                      // field in. It is 13 against the name's 13, so the name
                      // still leads: by ink tier, by face and by weight.
                      style: skin.text.monoIdent.style(color: quietInk),
                      maxLines: 1,
                    ),
                  ],
                  if (count != null) ...<Widget>[
                    const SizedBox(width: TiqSpace.s2),
                    Text(
                      '$count',
                      style: skin.text.axisLabel.style(color: quietInk),
                      maxLines: 1,
                    ),
                  ],
                  if (isExpander) ...<Widget>[
                    const SizedBox(width: TiqSpace.s2),
                    // The row chevron, quarter-turned: down is shut and up is
                    // open. A `RotatedBox` is a layout, not a transform with a
                    // layer — nothing here calls `saveLayer`.
                    RotatedBox(
                      quarterTurns: expanded! ? 3 : 1,
                      child: SoftRowChevron(color: quietInk, extent: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Write back what the sheet popped. Null is a dismissal and changes nothing;
/// [allTerritoriesToken] is the clear.
void applyTerritory(WidgetRef ref, DashboardFilter filter, String? chosen) {
  if (chosen == null) return;
  ref
      .read(dashboardFilterProvider.notifier)
      .set(
        chosen == allTerritoriesToken
            ? filter.copyWith(clearTerritory: true)
            : filter.copyWith(territoryId: chosen),
      );
}

/// THE FLOOR'S SCOPE SHEET — the window chips and the territory list in one
/// modal, opened from the plate's eyebrow.
///
/// One sheet rather than two, because unify §1.10 gives this product one modal
/// container and forbids stacking: a territory sheet opened from inside a
/// window sheet is the thing that rule exists to stop. The rows are
/// [territoryOptions], the same rows the overview's sheet shows.
///
/// A window chip applies and leaves the sheet up, because changing the window
/// is something a manager does two or three times in a row. A territory row
/// applies and closes, because it is the answer to the question they opened
/// the sheet with.
Future<void> showDashboardScope(BuildContext context, WidgetRef ref) async {
  final chosen = await showTorchSheet<String>(
    context,
    builder: (sheetContext) => _ScopeSheet(parentRef: ref),
  );
  applyTerritory(ref, ref.read(dashboardFilterProvider), chosen);
}

class _ScopeSheet extends ConsumerWidget {
  const _ScopeSheet({required this.parentRef});

  /// The ref the sheet writes the window through. A sheet is pushed onto the
  /// root navigator, so its own `ref` belongs to a subtree that is torn down
  /// when it closes; the window applies *while the sheet is up*, so it has to
  /// be written through the screen's.
  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(dashboardFilterProvider);

    return TorchSheet(
      semanticsLabel: l10n.dashFilters,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScopeSheetHeader(title: l10n.dashFilters),
          const SizedBox(height: TiqSpace.s3),
          // THE WINDOWS WRAP, THEY DO NOT SCROLL. As a rail two of the five
          // were off the right edge with no affordance — see the library note
          // for the measured positions. A `Wrap` is the whole fix: every
          // window is on screen, at the cost of a second 44dp line.
          //
          // The bleed stays because the chips still carry a gutter of their
          // own at each end; it is the rail's `padding` that is gone.
          //
          // AND IT IS ONE OF THE TWO PLACES THAT STILL STATES ITS OWN AMOUNT.
          // A sheet is mounted in the navigator's overlay, not under the shell
          // that opened it, so there is no [TorchGutter] overhead to read and
          // the sheet's own padding is the only answer. See [TorchBleed.extra].
          TorchBleed(
            extra: context.skin.space.gutter * 2,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.skin.space.gutter,
              ),
              child: Semantics(
                container: true,
                label: l10n.dashFilters,
                child: Wrap(
                  spacing: TiqSpace.s2,
                  runSpacing: TiqSpace.s2,
                  children: <Widget>[
                    for (final range in DashboardRange.values)
                      // `IntrinsicWidth`, AND IT IS LOAD-BEARING.
                      //
                      // [TorchFilterChip] centres its painted pill inside its
                      // 44dp target with a `Center`, and a `Center` given a
                      // BOUNDED width expands to fill it. In the rail the
                      // width is unbounded — it is a horizontal `ListView` —
                      // so the chip shrink-wraps and nobody had ever noticed.
                      // Dropped straight into a `Wrap` the same chip measured
                      // the full 350dp of sheet and the five of them stacked
                      // into five rows: measured 20..370 at y=165, 217, 269,
                      // 321, 373, which is 260dp of chrome for 96dp of chips.
                      //
                      // This is the local fix rather than a `widthFactor` on
                      // the chip's own `Center`, because that is a core
                      // component with twenty-odd call sites and this branch
                      // is allowed to change one sheet. It clamps rather than
                      // overflows: `RenderIntrinsicWidth` tightens to the
                      // child's max intrinsic width **bounded by the incoming
                      // constraints**, so an Afrikaans label at 2.0× wraps to
                      // two lines inside the chip exactly as it does today.
                      IntrinsicWidth(
                        child: TorchFilterChip(
                          key: ValueKey<String>('scope-range-${range.name}'),
                          label: rangeLabel(l10n, range),
                          selected: range == filter.range,
                          onSelected: () => parentRef
                              .read(dashboardFilterProvider.notifier)
                              .set(filter.copyWith(range: range)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: TiqSpace.s4),
          territoryOptions(context, ref, filter, context),
        ],
      ),
    );
  }
}
