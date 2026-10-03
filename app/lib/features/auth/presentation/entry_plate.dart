import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/display_headline.dart';
import '../../../core/widgets/torchlight/plate/plate.dart';
import 'entry_brand.dart';

/// THE PHOTOGRAPHIC PLATE, ON THE DOOR.
///
/// The object The Floor opens with, at the top of `/login`: the wordmark small
/// on the picture, the headline and the sentence under it at the picture's
/// foot, and the form on the ground below. The owner chose it out of three
/// directions on 30 September 2026 — *"A the plate"* — and the argument was
/// that **the plate is the one object nobody else has.** It is on The Floor,
/// it carries the territory, and the palette was built around it. Putting it
/// on the door means the product looks like itself before anyone has typed a
/// character.
///
/// It is [TiqPlate]. Not a copy of it, not "its tone and scrim" lifted out —
/// the same widget, with the same per-skin tone, the same bottom-up scrim, the
/// same text-safe zone, the same strip light and the same fit ladder. Two
/// things had to be generalised to let it stand here and both are named below.
///
/// ## 1. NOTHING ON THIS SCREEN KNOWS WHERE ANYONE WORKS
///
/// This is the constraint the mockup did not survive. The reference line read
/// *"Gauteng North is waiting · Fourteen stores on today's route"*, and on a
/// door that is **a lie**: before sign-in there is no tenant, no territory, no
/// route and no count. This product's whole position is that it does not
/// invent figures, and the one screen where inventing one would be easiest is
/// the one screen where every reader would see it.
///
/// So the plate carries no new copy at all. [headline] and [supporting] are
/// `loginHeadline` and `loginSubtitle` — *"Sign in to get to work."* and *"Use
/// your work email and password."* — the two strings the masthead was already
/// printing, moved onto the picture and not rewritten. Both are true of
/// everyone who has not signed in yet, both are already in Afrikaans, and
/// neither implies a territory. The picture is the same way: `ALL.jpg` is the
/// **all-territories** view, so the one place image that asserts nothing about
/// where the reader works is the one on the door.
///
/// ## 2. AMBER — THE BUTTON WINS, IN BOTH SKINS
///
/// The plate's strip light is an amber object and the sign-in button already
/// is one. `TorchScope`'s ladder is `primaryCommit -> plateStripLight`, so on
/// a Day budget of one the light **cannot** win: the primary outranks it and
/// the surplus claim is denied. That decides Day by arithmetic.
///
/// Night has two grants and could afford both, and it still does not get them.
/// The light is not claimed on this route in **either** skin, and there are
/// two reasons:
///
/// * **An empty form carries zero amber in every skin.** That is not a new
///   rule — it is the row `entry_amber_census_test.dart` has asserted since
///   #494, with its own reason written next to it: *the first screen anyone
///   sees is also the screen with the least reason to be lit, because nothing
///   on it is ready to commit yet*. A strip light lit on arrival would put
///   amber on a screen where nothing is armed.
/// * **A door that is lit differently in the two skins is two doors.** If
///   Night lit the strip and Day could not, the plate would be a different
///   object depending on the skin, on the one screen a person cannot change
///   their skin preference from an account they do not have yet.
///
/// So [claimId] is declared nowhere. `TorchScope.lit` answers false for an id
/// no route claimed, which is a supported answer and not a failure, and
/// `_StripLight` then draws its documented unlit form — a 2px `ink1` rule at
/// the same y. The census table is unchanged by this screen: 0 on an empty
/// form, 1 when armed, and the one is the button.
///
/// ## 3. THE FOLD, WHICH IS NOT THE FLOOR'S FOLD
///
/// [PlateSpec] budgets a plate as `min(clamp(0.40 × vh, 200, tallest), vh −
/// ground)`, and until now `ground` and `tallest` were the literals 440 and
/// 312 — **The Floor's decision rows, and what an 844dp phone has left after
/// them.** Neither number is about this screen. What is under the plate here
/// is the sign-in form, so this file passes its own two:
///
/// * [tallest] is 250, which is the mockup's proportion: roughly the top 250
///   of 844.
/// * [ground] is what has to be on screen **beside** the plate, measured in
///   `entry_plate_test.dart` rather than guessed, and grown with the text
///   scale by [groundFor].
///
/// ### The reserve counted a pinned bar against a scroll, three times
///
/// This number was 520, then 566, and it took three owner reports to be
/// recognised as a defect rather than a tuning problem. The first two rounds
/// answered by lowering the per-screen `shortest` — 200 to 150 — which bought
/// fifty dp of viewport and left the cliff at 716, still inside the range of
/// ordinary browser windows. The three sightings, against the one rule:
///
/// | reported | `vh − 566` | ≥ 200? | ≥ 150? |
/// |---|---|---|---|
/// | a browser window at 749 | 183 | no | yes |
/// | a phone at 810, a browser at 749 | 244 / 183 | yes / **no** | yes / yes |
/// | **a browser window at 708** | **142** | no | **no** |
///
/// The middle row is the one that cost the most to read: the same build drew
/// two different screens 66dp apart, and the conclusion from outside was that
/// the web app had not been rebuilt. It had. The third is eight dp under the
/// floor the second round had just bought.
///
/// 566 was documented as *the top of the headline to the foot of the commit
/// action*. **On the phone shape the commit action is not in the scrolling
/// column at all.** [EntryFrame] hands `primary` and `underPrimary` to
/// [TorchShell], which puts them in a [TorchThumbZone] that is a *sibling* of
/// the scroll view — `Column(Expanded(body), bottom)`. Its height is already
/// taken out of the body by that `Expanded`. Counting it again inside the
/// plate's reserve subtracted it twice.
///
/// Worse, the measurement that produced 566 measured the pinned bar. At
/// 390×844 the plate's foot is at 266 and the foot of "Forgot password?" is at
/// 832, twelve dp off the bottom edge: `566 = 844 − 266 − 12`. There is no
/// content in that number — it is the 844dp phone's own leftovers, so the test
/// that "proved" it could not have failed on any viewport.
///
/// ### What the reserve actually is
///
/// The screen scrolls. Everything below the first field is reachable by the
/// scroll it already has, so the honest reserve is what must be visible beside
/// the plate for a person to see this is a sign-in and start typing: the
/// headline (which is *on* the plate) and the whole first field. Measured at
/// 390 wide in Schibsted Grotesk, at 1.0×, by `entry_plate_test.dart`:
///
/// | piece | dp |
/// |---|---|
/// | the shell's top inset (`s4`) | 16 |
/// | `blockGap`, plate to first field | 24 |
/// | the email field, whole | 78 |
/// | the pinned thumb zone, outside the scroll | 142 |
/// | **[ground]** | **260** |
///
/// (82 and 146 against a 268 total until the prose scale came down 13/14 on
/// 1 October 2026. Both are type-driven heights; the gap and the inset are
/// tokens and did not move.)
///
/// That arithmetic, and not a clip, is what answers the short phone. The
/// picture now survives every viewport down to **410dp** — `410 − 260` is
/// 150, the [shortest] plate the door accepts. There is no phone and no
/// browser window in that band, which is the point: a cliff that has been
/// moved three times has to end up somewhere nobody can land on it.
///
/// A 360×640 handset therefore draws the photograph, where 566 dropped it.
/// Checked rather than assumed: at 640 the scroll viewport is 494, the plate's
/// foot is at 266, and the email and password fields land at 290–372 and
/// 392–474. **Both fields are above the fold with the picture up**, and the
/// two checkboxes scroll — which they did at 566 too, because the band it drew
/// instead was 183dp of type, not the 96 the old prose claimed.
///
/// The collapsed band stays and still means what it says: under [shortest] a
/// photograph with type on it is a smear, and a band of plain type is the
/// honest answer. What changed is that the boundary is now arithmetic about
/// this screen instead of an accident of the 844dp phone it was measured on.
///
/// ## 4. BOTH OF [EntryFrame]'S SHAPES
///
/// The plate is the first child of the column, so it is inside whichever shape
/// the frame chose and needs no branch of its own. On the phone shape it is
/// the width of the screen less the gutter; on the page shape it is the width
/// of the reading column, 480. **The height is the same 250 in both**, and
/// that is a decision rather than an oversight: the plate heads a *column*,
/// the column is the same form at both addresses, and a plate that grew on a
/// desktop would be a picture getting bigger because the window did — which is
/// the complaint #495 exists to have fixed. What changes between the two is
/// the crop's aspect, 358×250 against 480×250, and `BoxFit.cover` is what that
/// is for.
/// ## 5. FOUR SCREENS NOW, AND THE RESERVE IS THE ONE THING THAT DIFFERS
///
/// `/forgot-password`, `/account/password` and `/update-required` wear this
/// plate as well, through [AccountFrame] — the owner, 3 October 2026: *"Lets
/// fix the change password page, it's outdated from the app"*. The redesign
/// of #494 landed on the door and on nothing else, so the three screens
/// behind it kept a 96dp `TorchAppHeader`, a `titleM` heading and a disabled
/// commit, and stood next to a sign-in screen they no longer resembled.
///
/// Everything above is unchanged by that and none of it is per-screen except
/// §3: what has to be on screen *beside* the plate is a fact about the form
/// under it, and the account screens' form is not sign-in's. So the reserve
/// moved out of three constants into [EntryPlateReserve], of which
/// [EntryPlateReserve.door] is the numbers argued for in §3 and
/// [EntryPlateReserve.account] is the account frame's own, measured by
/// `account_plate_test.dart` in the same way and for the same reason.
///
/// **The account screens have MORE room than the door, not less**, which is
/// the opposite of what counting fields would suggest. Change password has
/// three fields and reset password has four, against sign-in's two — but the
/// fields below the first one are reached by the scroll the screen already
/// has, and §3 is the long version of why that is the whole answer. What the
/// account screens do not carry is sign-in's "Forgot password?" under the
/// commit, so their pinned thumb zone is 102dp where the door's is 142.
class EntryPlate extends StatelessWidget {
  const EntryPlate({
    super.key,
    required this.headline,
    this.supporting,
    this.leading,
    this.reserve = EntryPlateReserve.door,
  });

  /// THE TOP SLOT'S ONE OCCUPANT — the way out, where there is one.
  ///
  /// The account screens' back arrow, and nothing else today. It is here
  /// rather than in a `TorchAppHeader` above the plate because that header is
  /// 96dp before it prints a word ([TorchAppHeader.minHeightFor]) and it
  /// printed the same sentence the plate's headline now prints — the
  /// duplication `login_screen.dart` deleted on the door, one component up.
  /// The plate already reserves a band for a small control and already
  /// scrims it, so the arrow costs the fold nothing.
  ///
  /// **It REPLACES the wordmark rather than standing beside it**, and that is
  /// a measurement before it is a taste. Beside it, at 360dp wide and 2.0×,
  /// the arrow takes 56 of the 320dp inner width and the mark wraps to two
  /// lines: the slot becomes 94dp, and `PlateSpec.topSlotInset` plus 94 runs
  /// 15dp past `PlateSpec.stripLightY` on a 250dp plate. `plate_spec.dart`
  /// records what a control painted across the light costs — the census reads
  /// one cut light as two objects. One occupant is 48dp, 56 from 1.3× up, and
  /// clears it at every size and scale with 23dp to spare.
  ///
  /// It is also the better reading of the slot. **The mark says which product
  /// before anyone has typed a character**, which is a thing the door needs to
  /// say and these three do not: `/account/password` is behind a session,
  /// and `/forgot-password` and `/update-required` are both one step from a
  /// sign-in screen that has just said it. So the slot carries one thing —
  /// the mark on the door, the way out on a screen that has one.
  final Widget? leading;

  /// `loginHeadline`. Printed by a [TorchDisplayHeadline], which is the same
  /// widget the masthead used and the reason the header landmark a screen
  /// reader jumps to on arrival survives this change.
  final String headline;

  /// `loginSubtitle`. One line of `body` in `ink2` under the headline.
  ///
  /// **Null on the three account screens, and that is a decision.** None of
  /// them has a second sentence that is true in one line: reset password's
  /// `forgotIntro` is three sentences about a code a manager reads out and
  /// stays on the ground under the plate where it has room to wrap, and
  /// change password has no such sentence at all. Inventing one for the
  /// picture is the §1 mistake with a different subject.
  ///
  /// It also happens to be the direction the recorded [tallest] defect wants:
  /// the cluster this slot is part of is what the text zone has to hold, so a
  /// headline on its own needs much less of the plate than a headline and a
  /// sentence. `account_plate_test.dart` prints both numbers.
  final String? supporting;

  /// What has to stay on screen beside this plate, and how it grows with the
  /// text scale. The door's by default; see §5.
  final EntryPlateReserve reserve;

  /// The bundled picture. See the note beside it in `pubspec.yaml` for why
  /// this one and why bundled.
  static const String asset = 'assets/images/entry-plate.jpg';

  /// The id the strip light would be lit under, **declared by no route**. It
  /// exists so the widget can ask and be told no, which is the whole of §2
  /// above.
  static const String claimId = 'entry-plate-light';

  /// The mockup's proportion: roughly the top 250 of 844.
  ///
  /// ## ⚠ KNOWN DEFECT, RECORDED AND UNFIXED — the headline shrinks at 1.3×
  ///
  /// **This number is a flat 250 that never heard about the text scale, and
  /// at 1.3× and above the plate's own headline renders smaller than the
  /// field labels under it.** The screen's header becomes the smallest prose
  /// on screen, and it inverts hardest for the reader who turned the type up,
  /// which is the reader the setting exists for.
  ///
  /// The cause is not the fit ladder. [TiqPlate] lays the hero out in a
  /// `FittedBox(scaleDown)` inside a box of `0.52 × height − 16`, and that box
  /// is sized by this constant — a 1.0× number. The prose inside it grows with
  /// the scale and the box does not, so the ladder does the only thing it can.
  /// **The box is wrong, not the ladder.** Proven by rendering the same hero
  /// at 2.0× in two plates, 80dp apart:
  ///
  /// * `scratchpad/entry-reserve/plate-2.0x-338dp.png` — what the cap gives
  /// * `scratchpad/entry-reserve/plate-2.0x-418dp.png` — what the words need
  ///
  /// ### The obvious fix does not work, and this is the disproof
  ///
  /// The obvious move is to grow this with the scale exactly as [groundFor]
  /// grows the reserve — a `tallestFor(scale)`. **It cannot work**, because
  /// `tallest` is a ceiling on a value that is already capped by `0.40 × vh`:
  ///
  /// ```dart
  /// proportional = (viewportHeight * 0.40).clamp(200.0, tallest);
  /// height       = min(proportional, viewportHeight - ground);
  /// ```
  ///
  /// Set `tallest` to 100000 and nothing moves. The resolved heights are
  /// `0.40 × vh` at every size — 256 at 640, 283 at 708, 338 at 844, 373 at
  /// 932 — while an 844 viewport *affords* 508 at 2.0× (844 − `groundFor(2.0)`
  /// = 844 − 336; it was 496 when the reserve was 268 + 80). **Affordability
  /// is never the binding term on a phone; the proportion is.** Raising a
  /// ceiling above a binding cap changes nothing.
  ///
  /// ### What the plate actually needs, measured
  ///
  /// **RE-MEASURED 1 October 2026, in Schibsted Grotesk at the reduced prose
  /// scale.** The previous table was Onest's at `display` 40 and its own note
  /// said to re-measure the whole thing if the prose face changed. Both
  /// changed on the same day: the face, and then the scale, which took the
  /// display ladder from 40/32/26 to 37/30/24.
  ///
  /// The minimum plate height at which the rendered headline stops being
  /// shrunk. The plate puts the hero in a `FittedBox(scaleDown)` inside
  /// `Positioned(top: textZoneTop, bottom: s4)`, so the box is **`0.52 × H −
  /// 16`** at 240dp of plate and above and **`0.58 × H − 16`** below it, where
  /// `textZoneTop` is the shorter 0.42 fraction. A `FittedBox` transforms its
  /// child rather than re-laying it out, so the cluster's own `RenderBox.size`
  /// is its natural height and the number below is
  /// `(natural + 16) / fraction`. Checked against a direct sweep at 1.0×,
  /// which is the one row the plate can actually reach: derived 211, observed
  /// **210.4**.
  ///
  /// | scale | cluster natural | 360 | 390 | 395 | 430 | 1280 (plate 440) |
  /// |---|---|---|---|---|---|---|
  /// | 1.0× | 106 | 211 | 211 | 211 | 211 | 147 |
  /// | 1.3× | 134 | 289 | 289 | 289 | 289 | 176 |
  /// | 1.6× | 162–172 | 362 | 362 | 362 | **343** | 206 |
  /// | 2.0× | 188–272 | **393** | **554** | **554** | **439** | 274 |
  ///
  /// Against the `0.40 × vh` ceiling, which `tallest` cannot raise:
  ///
  /// | viewport | ceiling | 1.0× | 1.3× | 1.6× | 2.0× |
  /// |---|---|---|---|---|---|
  /// | 360×640 | 256 | ✓ | ✗ | ✗ | ✗ |
  /// | 395×708 | 283 | ✓ | **✗ (by 6dp)** | ✗ | ✗ |
  /// | 390×844 | 338 | ✓ | **✓** | ✗ (by 24dp) | ✗ |
  /// | 430×932 | 373 | ✓ | ✓ | **✓** | ✗ |
  /// | 1280×1800 | 720 | ✓ | ✓ | ✓ | ✓ |
  ///
  /// **Nine of the twelve phone-and-window cells are blocked, where eleven
  /// were.** 1.0× needs 211 against this constant's 250, so normal type now
  /// has 39dp of headroom rather than 27.
  ///
  /// Two things moved in opposite directions and both are worth knowing:
  ///
  /// * **430×932 at 1.6× came unblocked.** It needed 383 against a 373
  ///   ceiling and now needs 343. One real cell recovered, for free, out of a
  ///   change made for other reasons.
  /// * **2.0× at 390 and 395 got WORSE — 418 before, 554 now.** Not a
  ///   regression in the prose: a rung of the fitting ladder moved out from
  ///   under it. At 2.0× on a 310dp text column the headline takes three lines,
  ///   which is the `display.m` rung; at 40 it took four and dropped to the
  ///   `display.s` floor, where it was already as small as the ladder goes.
  ///   Smaller type bought a line back and the ladder spent it on a bigger
  ///   rung. 360 wide still reaches four lines and still floors, which is why
  ///   it needs 393 and the wider screens need 554 — **the inversion that used
  ///   to run the other way now runs this way.** A `proportion` surface still
  ///   cannot be a straight line, and it cannot be a line in width either.
  ///
  /// ### The lever that does work
  ///
  /// A per-screen **`proportion`** on `PlateSpec.heightFor`, defaulting to
  /// 0.40 — the same move already made for [ground], [tallest] and [shortest],
  /// whose own note records why: *named parameters with The Floor's values as
  /// defaults, so The Floor's call site is unchanged and its arithmetic is
  /// bit-for-bit what it was.* The Floor stays untouched by construction.
  ///
  /// With the proportion lifted, affordability becomes the only limit and the
  /// band returns only where it is honestly the answer — 1.6× and 2.0× on a
  /// 640dp handset, 2.0× on a 708dp window. Two things it must carry:
  ///
  /// * **A width × scale surface, not a line.** 1.3× needs 307 at 390 wide and
  ///   322 at 360; 1.6× needs 383 against 482. Headline wrapping drives it, so
  ///   it is not the straight line [groundFor] is.
  /// * **`tallestFor(1.0)` pins to 250, not the measured 223**, or the plate
  ///   the owner approved shrinks on every screen at normal type, including
  ///   the 1280×1800 page.
  ///
  /// ### Why it is not built here
  ///
  /// The face change happened — Schibsted Grotesk, 1 October 2026 — and the
  /// table above has been re-measured for it, including the scale reduction
  /// that followed on the same day. **The numbers are true again and the
  /// `proportion` route is ready to build from them.**
  ///
  /// It is still not built here, for a narrower reason than before: it needs a
  /// `proportion` parameter on `PlateSpec.heightFor` and a width × scale
  /// surface behind it, and that is a change to the component The Floor shares.
  /// A type change is not where that lands.
  ///
  /// **The warning the old note carried stands, and this round proved it.**
  /// Every number above is a headline-wrapping measurement in one face at one
  /// scale; the previous set was Onest's, and the face swap plus the reduction
  /// moved every cell — one of them (2.0× at 390) by 136dp, and in the
  /// direction nobody would have guessed. Re-measure before using them again,
  /// and use `test/features/auth/entry_plate_headline_fit_test.dart`, which
  /// is the harness every cell above came out of and which now asserts them
  /// — so a face or scale change fails there with the new numbers printed,
  /// rather than leaving this table quietly wrong.
  static const double tallest = 250;

  /// The shortest photographic plate the door will accept — **150, against
  /// The Floor's 200, and it is an argument about the picture, not about the
  /// fold.**
  ///
  /// On The Floor a plate is context above a list of work, so a 150dp strip is
  /// room the work needs. Here the plate IS the screen: the owner chose this
  /// direction out of three *because* the picture is the product's signature.
  ///
  /// It is **not** load-bearing any more, and that is the repair. 150 was put
  /// here to buy fifty dp of viewport back from a reserve that was double
  /// counting the thumb zone — 766 down to 716 — and the arithmetic it was
  /// defending against is gone; see §3. With [ground] at 260 a plate shorter
  /// than The Floor's 200 only occurs between a 410 and a 460dp viewport, and
  /// nothing lands there. (It was 418 to 468 when the reserve was 268; the
  /// prose reduction moved the whole band 8dp down.) What the number still says is the thing it ought to
  /// have said on its own: under 150dp a photograph with type over it is a
  /// smear, and the band is better.
  ///
  /// **Lowering it again would be the fourth round of the same mistake.** If a
  /// viewport is ever reported without a picture, the reserve above is what to
  /// re-measure.
  static const double shortest = 150;

  /// What must be on screen **beside** the plate at 1.0× — **260, measured.**
  ///
  /// The screen scrolls, so this is not the height of the form. It is the top
  /// inset (16) plus the block gap and the whole first field (24 + 78) plus
  /// the pinned thumb zone (142), which is a sibling of the scroll view and
  /// not a row inside it. §3 has the table and the three reports that came of
  /// getting it wrong. `entry_plate_test.dart` re-measures all four pieces off
  /// the rendered screen and fails with the number to put here.
  ///
  /// It was **268** until the prose scale came down 13/14 on 1 October 2026,
  /// which took 4dp off the email field (82 → 78) and 4dp off the thumb zone
  /// (146 → 142). Both are type-driven heights and both moved in the direction
  /// that gives the picture more room, not less.
  static const double ground = 260;

  /// How much [ground] grows per unit of text scale — **80, measured.**
  ///
  /// Three of the four pieces carry type and two of them grow: the email field
  /// (78 → 114) and the thumb zone (142 → 178). The gap and the inset are
  /// tokens and do not. The measured reserve is **260 at 1.0×, 282 at 1.3×,
  /// 304 at 1.6× and 332 at 2.0×** — the binding segment is 1.0× → 1.3×, whose
  /// slope is 73.3. The number here is rounded up to **76** so [groundFor] is
  /// never *under* the measured reserve at a scale in between: it gives 282.8
  /// at 1.3×, 305.6 at 1.6× and 336 at 2.0×, each a shade over what was
  /// measured.
  ///
  /// Re-measured on 1 October 2026 with the reduced prose scale. It was 80
  /// against a measured slope of 76; both numbers came down because the three
  /// pieces that carry type are all smaller, and the reserve therefore grows
  /// more slowly as well as starting lower.
  static const double groundProse = 76;

  /// The reserve at a given text scale.
  ///
  /// Linear, and it no longer carries the weight it used to. At 2.0× it is
  /// 336, so the collapse boundary moves from a 410dp viewport to 486 and the
  /// picture survives every real device at every scale the app allows. (348
  /// and 498 before the 1 October 2026 prose reduction; both came down with
  /// the reserve.)
  ///
  /// ### WHAT THAT CHANGED, SAID OUT LOUD
  ///
  /// At 390×844 and 2.0× this screen used to collapse to the band, and now it
  /// does not. **That collapse was an accident, not a decision**: the old
  /// reserve was 566 and its prose share was a flat, unmeasured 200, so 2.0×
  /// put the reserve at 766 and an 844dp phone had 78dp left. Nobody chose
  /// 2.0× as a boundary; it fell out of two guessed numbers multiplied
  /// together. Reproducing it by tuning [groundProse] back up would be the
  /// same cliff engineering this fix exists to end, so it is not reproduced.
  ///
  /// **Keeping the picture up at 2.0× is right; what the picture then shows
  /// is a separate, recorded defect.** At 1.3× and above the headline on the
  /// plate renders smaller than the field labels under it, and that is true
  /// whether or not this reserve collapses — it has been true at 1.3× and
  /// 1.6× since the screen was built. Collapsing would not fix it either; it
  /// would only hide it by dropping the photograph at settings plenty of
  /// people use, which is the defect the owner has reported three times.
  ///
  /// The cause, the measurements, the disproof of the obvious fix and the
  /// lever that does work are all on [tallest]. **Do not answer it from
  /// here.** The reserve is about the screen *under* the plate; how tall the
  /// plate must be to carry its own words is the plate's question. Conflating
  /// the two is exactly how this number came to be 566.
  static double groundFor(double textScale) =>
      ground + (textScale - 1) * groundProse;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final scale = MediaQuery.textScalerOf(context).scale(1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The hero has to be laid out at a real width. `_PhotographicPlate`
        // wraps it in a `FittedBox(scaleDown)`, which passes UNBOUNDED width
        // to its child — fine for a figure, which is one glyph run, and wrong
        // for prose: `TorchDisplayHeadline` reads `constraints.maxWidth` to
        // pick its size and returns the 40 step unconditionally when that is
        // infinite, so the headline would never wrap and the FittedBox would
        // then scale a single long line down to nothing. Giving the cluster
        // the width it will actually occupy makes the fit ladder a floor
        // again rather than the only rule.
        final text = constraints.maxWidth - 2 * skin.space.gutter;

        return TiqPlate(
          claimId: claimId,
          viewportHeight: MediaQuery.sizeOf(context).height,
          ground: reserve.at(scale),
          tallest: tallest,
          shortest: reserve.shortest,
          image: const AssetImage(asset),
          // THE TOP OF THE PICTURE CARRIES TYPE HERE, SO IT GETS A SCRIM.
          //
          // The Floor's top slot is a chip with its own surface and needs
          // none. The wordmark is bare type on bare picture, and **Night**
          // does not survive that: the tone's ceiling is `#666666`, the sky
          // behind the mark is the brightest thing in the frame so it sits at
          // the ceiling, and `ink2` against it is 3.60:1. With the scrim it
          // is 6.41. Day clears either way (6.88 / 7.32) because its lift
          // makes the same sky pale rather than dark.
          //
          // All four numbers are measured over the shipped asset by
          // `entry_plate_test.dart`, which fails with them printed.
          topScrim: true,
          // No printed caption, following The Floor's owner override of 25
          // September 2026: what the picture is travels as [semanticLabel]
          // and not as a line of type on the plate.
          caption: null,
          // WHAT IT IS, SAID PLAINLY. "Illustration" because it is generated,
          // and "somewhere" because it is nowhere in particular — naming a
          // place here would be the same invention the copy above refuses.
          semanticLabel:
              'An illustration of a trade route at first light. Generated, '
              'and not a photograph of anywhere in particular.',
          // The picture is bundled, so a decode failure is a broken build
          // rather than a missing upload. The sentence still has to be true
          // and still may not name a place.
          fallbackSentence: 'A drawing, in place of the picture.',
          // THE WORDMARK, SMALL, AT THE TOP OF THE PICTURE. The same 24dp
          // compact mark the masthead carried, at the same address on the
          // plate The Floor puts its scope chip.
          // THE WAY OUT LEFT, THE MARK BESIDE IT — 3 October 2026.
          //
          // This slot carried the skin cycle in the corner opposite the mark
          // from 30 September, on the standing rule that no screen may be
          // without the cycle. **The owner struck the control the next day**
          // — *"That change of theme on the sign in we can remove it. Let's
          // only make the change of theme only on settings."* — and it came
          // off the door then and off the three account screens on 3 October.
          // The slot is not empty, because the account screens have the thing
          // the door does not: somewhere to go back to. See [leading].
          //
          // `Flexible`, not a `Spacer` between two fixed children: at 2.0x the
          // wordmark is twice the width it is at 1.0 and this Row overflowed
          // by 124 logical pixels the first time it was written. The arrow is
          // a fixed tap target and may not shrink; the mark is type and can.
          topSlot:
              leading ??
              Semantics(
                container: true,
                child: const EntryBrand(monogram: 24, compact: true),
              ),
          hero: SizedBox(
            width: text < 0 ? 0 : text,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // THREE NODES, NOT ONE, AND `container` IS WHAT MAKES THEM
                // THREE.
                //
                // The masthead's mark, headline and sentence used to be three
                // children of the frame's list, so the viewport gave each one
                // its own semantics boundary and nothing had to be said. In
                // here they are one subtree under one boundary, and a
                // `Semantics` with `container: false` — which is the default,
                // and which is what `Semantics(header: true)` inside
                // [TorchDisplayHeadline] and the wordmark's own label both are
                // — *annotates the enclosing node* instead of making one. All
                // three coalesced: the header landmark announced "TradeIQ /
                // Sign in to get to work. / Use your work email and password."
                // as a single node.
                //
                // That is a regression in the exact thing #494 was careful
                // about. The screen has no app header, so this headline is the
                // one header node a reader can jump to on arrival, and a
                // landmark that reads out the whole masthead is not a landmark.
                // `login_screen_test.dart` pins all three separately.
                Semantics(
                  container: true,
                  child: TorchDisplayHeadline(headline),
                ),
                if (supporting != null) ...<Widget>[
                  SizedBox(height: skin.space.intraBlock),
                  Semantics(
                    container: true,
                    child: Text(
                      supporting!,
                      style: skin.text.body.style(color: skin.palette.ink2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// WHAT A SCREEN KEEPS ON SCREEN BESIDE ITS PLATE, AND THE FLOOR UNDER IT.
///
/// `PlateSpec.heightFor` is `min(clamp(0.40 × vh, 200, tallest), vh − ground)`
/// and `ground` is the only term in it that is a fact about the form rather
/// than about the picture. [EntryPlate] §3 is the long argument for what
/// belongs in it — *not* the form's height, because the screen scrolls, and
/// *not* the commit row twice, because the commit row is pinned outside the
/// scroll. What belongs in it is the top inset, the gap and the whole first
/// field, and the pinned thumb zone.
///
/// It was three constants on [EntryPlate] while the door was the only screen
/// with a plate. Three screens joined it on 3 October 2026 with a different
/// thing under the picture, and three constants is how a second plate gets
/// written instead of this one being used — which is word for word the reason
/// `PlateSpec` gave for taking `ground` and `tallest` off The Floor in the
/// first place.
@immutable
class EntryPlateReserve {
  const EntryPlateReserve({
    required this.ground,
    required this.prose,
    required this.shortest,
  });

  /// The reserve at 1.0×, in dp. Measured, never guessed: the test that owns
  /// each of these fails with the number to put here.
  final double ground;

  /// How much [ground] grows per unit of text scale. Linear, because the
  /// pieces that grow are type and the pieces that do not are tokens.
  final double prose;

  /// The shortest photographic plate the screen accepts; under it the plate
  /// collapses to the 96dp band.
  final double shortest;

  /// The reserve at a given text scale.
  double at(double textScale) => ground + (textScale - 1) * prose;

  /// `/login`. The three numbers §3 argues for, and nothing has moved.
  static const EntryPlateReserve door = EntryPlateReserve(
    ground: EntryPlate.ground,
    prose: EntryPlate.groundProse,
    shortest: EntryPlate.shortest,
  );

  /// ## THE THREE ACCOUNT SCREENS, EACH WITH ITS OWN, EACH MEASURED
  ///
  /// `account_plate_test.dart` renders all three at 390 **and 360** wide and
  /// prints the reserve it measured off the frame, at the four scales the app
  /// allows. Every cell below is the worse of the two widths — a paragraph
  /// takes more lines in a narrower column, and update required's reserve is
  /// 40dp larger at 360 than at 390 at 2.0× for exactly that reason. The test
  /// fails with the numbers to put here:
  ///
  /// | screen | 1.0× | 1.3× | 1.6× | 2.0× | `ground` | `prose` |
  /// |---|---|---|---|---|---|---|
  /// | change password | 215 | 226 | 237 | 255 | **216** | **40** |
  /// | update required | 197 | 241 | 265 | 381 | **200** | **185** |
  /// | reset password | 299 | 328 | 389 | 479 | **304** | **180** |
  ///
  /// **One reserve for the three was tried first and it is wrong.** Taking
  /// reset password's for all of them over-reserves change password by 84dp
  /// at 1.0× and by 228 at 2.0×, which costs that screen its photograph on a
  /// 360×640 handset at a scale where it provably has the room. The three
  /// differ for one reason worth stating: **change password puts the plate
  /// straight onto its first field, and the other two put a paragraph in
  /// between** — `forgotIntro` and `updateBody` — and a paragraph does not
  /// grow with the type so much as gain whole lines (60 → 78 → 128 → 200 for
  /// the first of those). That is also why their `prose` is three and four
  /// times change password's and why none of these surfaces is the straight
  /// line the door's is: each one's binding segment is the top of its range,
  /// not the bottom.
  ///
  /// Change password's 215 is **45dp under the door's 260**, which counting
  /// fields would not predict — it has three where sign-in has two. The
  /// fields below the first are reached by the scroll the screen already has,
  /// which is §3's whole argument; what the door carries and these do not is
  /// "Forgot password?" under the commit, so their pinned thumb zone is 97dp
  /// where the door's is 142.
  ///
  /// ## `shortest` IS 190 HERE, AND IT IS A CLEARANCE
  ///
  /// [EntryPlate.shortest] is 150 and says a photograph under 150dp with type
  /// over it is a smear. True here too, and not the binding number: these
  /// plates carry a **control**, and `PlateSpec.topSlotInset` (16) plus a tap
  /// target that reaches 56dp from 1.3× up has to clear
  /// `PlateSpec.stripLightY`, which is `0.38 × h`. `(16 + 56) / 0.38` is
  /// 189.5.
  ///
  /// It bites in **exactly one cell of the supported matrix** — reset
  /// password at 360×640 and 2.0×, where the reserve is 484 and the plate
  /// would otherwise be 156dp with a 72dp control standing 13dp into its own
  /// light. The band takes that cell instead, and the band has no light to
  /// cut and grows past its 96dp minimum rather than clipping. Every other
  /// screen, size and scale resolves at or above 228dp of photographic plate,
  /// so this constant is not load-bearing anywhere a person actually is —
  /// which is the property [EntryPlate.shortest]'s own note says to aim for
  /// after three rounds of moving it.
  static const EntryPlateReserve changePassword = EntryPlateReserve(
    ground: 216,
    prose: 40,
    shortest: 190,
  );

  /// `/update-required`. See the table on [changePassword].
  static const EntryPlateReserve updateRequired = EntryPlateReserve(
    ground: 200,
    prose: 185,
    shortest: 190,
  );

  /// `/forgot-password`. See the table on [changePassword].
  static const EntryPlateReserve resetPassword = EntryPlateReserve(
    ground: 304,
    prose: 180,
    shortest: 190,
  );
}
