import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/torchlight/tiq_skin.dart';

/// THE AMBER ALLOCATOR.
///
/// Burning Flame is a light source, never a label. A screen gets a fixed,
/// countable number of lit objects and the ladder below decides which of the
/// things that asked for one actually gets it. The count is the whole point:
/// "use amber sparingly" is a sentence nobody can fail, and every audit of
/// this app found the same twelve amber objects on one screen.
///
/// ## The arithmetic (unify §1.1, §4)
///
/// * **Night** — two grants in the composed frame. The nav's active tab is
///   slot 1 *whenever the nav renders*; content gets one grant on a tabbed
///   route and two on an untabbed one (in a visit, in a sheet, in a
///   full-screen state).
/// * **Day and Veld** — one grant, and it is the primary commit block. Zero
///   when nothing is armed.
///
/// The nav is **counted**, not exempt. Kit called it "reserved", manager
/// called it "exempt"; both produce the same number and "counted" is the
/// honest word for it.
///
/// ## The ladder (fixed precedence, unify §4)
///
/// 1. [TorchClaimKind.primaryCommit]
/// 2. [TorchClaimKind.plateStripLight]
/// 3. [TorchClaimKind.chartFocus]
/// 4. [TorchClaimKind.navCircle] — **only** on a route with no primary
/// 5. [TorchClaimKind.livePulse] — presence only, at most one per route
///
/// [TorchClaimKind.meterTick] is deliberately absent: a target tick is an
/// annotation, an annotation is a label, and the tick's silhouette (breaking
/// the track's top edge) is what carries it. It is ink-1 everywhere.
///
/// ## Resolution is static
///
/// The claim set is computed by the route's view model at construction and
/// per declared [phase] — never per frame. A grant that is recomputed while
/// the user scrolls is a grant that blinks, and a blinking light is the one
/// thing amber is not allowed to be unless it is the live pulse.
///
/// ## Failure mode
///
/// Over-claiming **asserts in debug** with the full ladder printed, and
/// **degrades gracefully in release**: the surplus claims simply lose, in
/// ladder order, and the frame renders correctly lit. A design rule must
/// never throw in front of a user in a back aisle during Stage 6.
enum TorchClaimKind {
  /// The one commit action on the route. Outranks everything.
  primaryCommit,

  /// A photographic plate's strip light.
  plateStripLight,

  /// Exactly one focus bar or one focus series in one chart.
  chartFocus,

  /// The role's standing action, in the circle outside the nav bar. Amber
  /// **only** on a route that has no primary commit — otherwise the circle is
  /// its ink form.
  navCircle,

  /// A breathing amber dot: a human mid-visit, a tool executing, a GPS fix
  /// being sought. Presence, never progress — an upload is progress, and
  /// progress is a report. One per route.
  livePulse,

  /// The 2px flame-700 rule under a focused text field. Counted, not exempt:
  /// it fits because the keyboard hides the nav, which returns that grant to
  /// content, so a focused field plus a lit primary is exactly two.
  textFieldFocus,

  /// The nav's active tab. Not claimed by a view model — [TorchScope] adds it
  /// itself when [navRenders] is true, so no route can forget to count it.
  navActiveTab,
}

/// Whether an over-claim throws in debug.
///
/// Always true in a running debug build. A test flips it to false to exercise
/// the **release** path — graceful degradation — without building in release
/// mode, which is the only way to prove that the thing a user meets is a
/// correctly lit frame rather than a red screen. Flipping it is the one
/// documented way past the assert, and it is deliberately not a constructor
/// argument, so no feature code can quietly opt out.
bool debugTorchAssertOverClaim = true;

/// Where a claim sits in the ladder. Lower sorts first.
int _rung(TorchClaimKind kind) => switch (kind) {
  TorchClaimKind.navActiveTab => 0,
  TorchClaimKind.primaryCommit => 1,
  TorchClaimKind.plateStripLight => 2,
  TorchClaimKind.chartFocus => 3,
  TorchClaimKind.navCircle => 4,
  TorchClaimKind.textFieldFocus => 5,
  TorchClaimKind.livePulse => 6,
};

/// One object asking to be lit.
@immutable
class TorchClaim {
  const TorchClaim(this.kind, {required this.id, this.subject = false});

  final TorchClaimKind kind;

  /// Stable within a route and a phase. Two claims with the same id are the
  /// same object re-declared, not two objects — a chart that rebuilds does not
  /// get a second grant.
  final String id;

  /// The route's **one** `subject` override: this object is what the screen is
  /// about, so it jumps the ladder. A second subject in one claim set is an
  /// over-claim in its own right and asserts.
  final bool subject;

  const TorchClaim.primaryCommit(String id) : this(TorchClaimKind.primaryCommit, id: id);
  const TorchClaim.plateStripLight(String id) : this(TorchClaimKind.plateStripLight, id: id);
  const TorchClaim.chartFocus(String id, {bool subject = false})
    : this(TorchClaimKind.chartFocus, id: id, subject: subject);
  const TorchClaim.navCircle(String id) : this(TorchClaimKind.navCircle, id: id);
  const TorchClaim.livePulse(String id) : this(TorchClaimKind.livePulse, id: id);
  const TorchClaim.textFieldFocus(String id) : this(TorchClaimKind.textFieldFocus, id: id);

  @override
  bool operator ==(Object other) =>
      other is TorchClaim &&
      other.kind == kind &&
      other.id == id &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash(kind, id, subject);

  @override
  String toString() =>
      'TorchClaim(${kind.name}, id: $id${subject ? ', subject' : ''})';
}

/// Why a claim did not get its grant.
enum TorchDenial {
  /// The budget was already spent by higher rungs.
  outranked,

  /// A nav circle on a route that has a primary commit. The ladder forbids
  /// this outright, not merely on budget.
  circleWithPrimary,

  /// A second live pulse on one route.
  duplicatePulse,

  /// On a light ground amber is not light any more — it is a block of paint
  /// carrying ink, and there is exactly one of those per screen: the primary
  /// commit action. Everything else that is amber in Night is something else
  /// here (the nav tab is an Abyssal block, the focus bar is ink-1, "you are
  /// here" is a disc with a white ring, the live pulse is a `lifted` dot and
  /// the word Live).
  notAmberOnLightGround,

  /// Every amber beneath an open modal sheet goes out, so the sheet's own
  /// scope genuinely owns the screen.
  extinguishedBySheet,
}

/// What [TorchScope] decided, computed once per route × phase.
@immutable
class TorchAllocation {
  const TorchAllocation({
    required this.budget,
    required this.granted,
    required this.denied,
    required this.overClaimed,
  });

  /// How many objects this skin allows in this composed frame.
  final int budget;

  /// The claim ids that are lit, in ladder order.
  final List<TorchClaim> granted;

  /// Everything that asked and lost, with the reason.
  final Map<TorchClaim, TorchDenial> denied;

  /// How many claims arrived beyond the budget. Zero on a well-built route.
  final int overClaimed;

  bool isLit(String id) => granted.any((c) => c.id == id);

  bool get isOverClaimed => overClaimed > 0;

  /// The message the debug assert prints, and the one the golden harness
  /// prints when it counts too many flame regions.
  String describe() {
    final buffer = StringBuffer()
      ..writeln('TorchScope: $budget grant(s), ${granted.length} taken.')
      ..writeln('  lit:');
    for (final c in granted) {
      buffer.writeln('    ${c.kind.name}  ${c.id}${c.subject ? '  (subject)' : ''}');
    }
    if (denied.isNotEmpty) {
      buffer.writeln('  unlit:');
      for (final entry in denied.entries) {
        buffer.writeln(
          '    ${entry.key.kind.name}  ${entry.key.id}  — ${entry.value.name}',
        );
      }
    }
    return buffer.toString();
  }
}

/// The InheritedWidget that sits at the top of a route and hands out the
/// route's amber.
///
/// ```dart
/// TorchScope(
///   skin: context.skin,
///   phase: 'loaded',
///   navRenders: true,
///   tabbedRoute: true,
///   claims: [
///     const TorchClaim.primaryCommit('check-in'),
///     const TorchClaim.chartFocus('worst-outlet'),
///   ],
///   child: ...,
/// )
/// ```
///
/// A widget that can emit amber asks `TorchScope.lit(context, 'check-in')`
/// and paints its ink form when the answer is false. It never asks "am I on a
/// dark ground" or "is there already an amber somewhere" — those are the
/// questions this widget exists to answer once.
class TorchScope extends InheritedWidget {
  TorchScope({
    super.key,
    required TiqSkin skin,
    required this.phase,
    required List<TorchClaim> claims,
    this.navRenders = false,
    this.tabbedRoute = false,
    this.beneathSheet = false,
    required super.child,
  }) : allocation = resolve(
         skin: skin,
         claims: claims,
         navRenders: navRenders,
         tabbedRoute: tabbedRoute,
         beneathSheet: beneathSheet,
       );

  /// The declared phase — `loading`, `loaded`, `empty`, `error`, `sending`.
  /// Resolution happens once per phase, never per frame.
  final String phase;

  /// True whenever the nav pill is on screen. Its active tab is slot 1.
  final bool navRenders;

  /// A tab root gets one content grant in Night; an untabbed route (a visit,
  /// a sheet, a full-screen state) gets two.
  final bool tabbedRoute;

  /// While a modal sheet is up, every amber on the route beneath it goes out.
  final bool beneathSheet;

  final TorchAllocation allocation;

  /// How many lit objects a skin permits in one composed frame.
  ///
  /// Night is two because a dark room can hold two lights and still have a
  /// brightest one. Day and Veld are one because on a light ground amber is
  /// not light any more — it is a block of ink-carrying paint, and two of
  /// those is two primary actions.
  static int budgetFor(TiqSkin skin) => skin.amberIsInk ? 1 : 2;

  /// Resolve a claim set. Pure, synchronous, and independently testable —
  /// the widget is a way to publish this, not where the rule lives.
  static TorchAllocation resolve({
    required TiqSkin skin,
    required List<TorchClaim> claims,
    bool navRenders = false,
    bool tabbedRoute = false,
    bool beneathSheet = false,
  }) {
    final budget = budgetFor(skin);
    final denied = <TorchClaim, TorchDenial>{};

    if (beneathSheet) {
      // Every amber beneath an open sheet is extinguished — including the nav
      // tab and the plate's light, which is what makes the sheet own the
      // screen without a 88% scrim hiding the held work behind it.
      for (final c in claims) {
        denied[c] = TorchDenial.extinguishedBySheet;
      }
      return TorchAllocation(
        budget: budget,
        granted: const <TorchClaim>[],
        denied: denied,
        overClaimed: 0,
      );
    }

    // De-duplicate by id: a chart that rebuilds re-declares the same claim.
    final unique = <String, TorchClaim>{};
    for (final c in claims) {
      unique.putIfAbsent(c.id, () => c);
    }
    var pending = unique.values.toList();

    // On a light ground the ONLY thing that may be amber is the primary
    // commit block. This is not a budget of one applied to the same ladder —
    // it is a different ladder with one rung, because every other object on
    // the ladder has a non-amber form there and takes it unconditionally.
    if (skin.amberIsInk) {
      final primaries = <TorchClaim>[];
      for (final c in pending) {
        if (c.kind == TorchClaimKind.primaryCommit) {
          primaries.add(c);
        } else {
          denied[c] = TorchDenial.notAmberOnLightGround;
        }
      }
      primaries.sort((a, b) => a.id.compareTo(b.id));
      final granted = primaries.take(budget).toList();
      for (final c in primaries.skip(budget)) {
        denied[c] = TorchDenial.outranked;
      }
      final allocation = TorchAllocation(
        budget: budget,
        granted: granted,
        denied: denied,
        overClaimed: primaries.length - granted.length,
      );
      assert(() {
        if (debugTorchAssertOverClaim && allocation.isOverClaimed) {
          throw FlutterError(
            'TorchScope over-claim on a light ground: '
            '${primaries.length} primary commit actions.\n\n'
            '${allocation.describe()}\n'
            'Day and Veld have exactly one amber block per screen and it is '
            'the primary commit action. Two primaries is two screens.',
          );
        }
        return true;
      }());
      return allocation;
    }

    // The nav's active tab is added here rather than declared by a route, so
    // no route can forget to count the chrome it did not draw.
    if (navRenders) {
      pending = <TorchClaim>[
        const TorchClaim(TorchClaimKind.navActiveTab, id: '__nav_active_tab__'),
        ...pending,
      ];
    }

    final hasPrimary = pending.any(
      (c) => c.kind == TorchClaimKind.primaryCommit,
    );

    // Ladder order, with the one `subject` override jumping the content rungs.
    // A subject never outranks the nav tab: chrome that changed colour per
    // route would read as a bug.
    pending.sort((a, b) {
      final ra = a.subject && a.kind != TorchClaimKind.navActiveTab ? 1 : _rung(a.kind);
      final rb = b.subject && b.kind != TorchClaimKind.navActiveTab ? 1 : _rung(b.kind);
      if (ra != rb) return ra.compareTo(rb);
      return a.id.compareTo(b.id);
    });

    final granted = <TorchClaim>[];
    var pulseTaken = false;
    var overClaimed = 0;

    for (final claim in pending) {
      if (claim.kind == TorchClaimKind.navCircle && hasPrimary) {
        denied[claim] = TorchDenial.circleWithPrimary;
        continue;
      }
      if (claim.kind == TorchClaimKind.livePulse) {
        if (pulseTaken) {
          denied[claim] = TorchDenial.duplicatePulse;
          continue;
        }
        pulseTaken = true;
      }
      if (granted.length < budget) {
        granted.add(claim);
      } else {
        denied[claim] = TorchDenial.outranked;
        overClaimed++;
      }
    }

    // `tabbedRoute` is not a second budget — it is the same arithmetic seen
    // from the content side, and it is asserted rather than applied so a route
    // that lies about itself is caught rather than silently re-budgeted.
    assert(() {
      if (navRenders && !tabbedRoute) {
        // A nav pill on a route that says it is untabbed is a contradiction in
        // the shell rather than an amber problem — but it changes the count,
        // so say so rather than silently re-budgeting.
        debugPrint(
          'TorchScope: navRenders is true on a route declared untabbed. The '
          'nav tab is counted as slot 1, so this route has one content grant, '
          'not two.',
        );
      }
      return true;
    }());

    final allocation = TorchAllocation(
      budget: budget,
      granted: granted,
      denied: denied,
      overClaimed: overClaimed,
    );

    assert(() {
      if (!debugTorchAssertOverClaim) return true;
      final subjects = unique.values.where((c) => c.subject).length;
      if (subjects > 1) {
        throw FlutterError(
          'TorchScope: a route may declare exactly one `subject` override, '
          'and this one declared $subjects. The subject is what the screen is '
          'about; two subjects means the screen is about two things.\n'
          '${allocation.describe()}',
        );
      }
      if (allocation.isOverClaimed) {
        throw FlutterError(
          'TorchScope over-claim: ${pending.length} amber claims against a '
          'budget of $budget.\n\n'
          '${allocation.describe()}\n'
          'Burning Flame is a light source, never a label. The ladder is '
          'primary commit -> plate strip light -> chart focus -> nav circle '
          '(no-primary routes only) -> live pulse. If the object that lost '
          'should have won, declare it `subject: true` and take the override; '
          'if two objects both need light, the screen is two screens.\n'
          'In release these claims are simply denied and the frame renders '
          'correctly lit — this assert exists so it is caught here instead.',
        );
      }
      return true;
    }());

    return allocation;
  }

  /// The nearest scope, or null outside one. Null is not an error: a widget
  /// that can emit amber is also usable in a Phase 1 golden with no route
  /// around it, and outside a scope it takes its ink form.
  static TorchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TorchScope>();

  /// Whether the object with this claim [id] is lit on this route right now.
  ///
  /// Outside a scope the answer is false — unlit is always the safe render.
  static bool lit(BuildContext context, String id) =>
      maybeOf(context)?.allocation.isLit(id) ?? false;

  @override
  bool updateShouldNotify(TorchScope oldWidget) =>
      oldWidget.phase != phase ||
      oldWidget.beneathSheet != beneathSheet ||
      !listEquals(oldWidget.allocation.granted, allocation.granted);
}
