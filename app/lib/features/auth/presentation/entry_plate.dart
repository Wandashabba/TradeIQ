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
/// * [ground] is what the form and the commit row need, measured in
///   `entry_plate_test.dart` rather than guessed, and **grown with the text
///   scale** by [groundFor]. The form under the plate is prose and prose gets
///   bigger; a reserve that did not move would keep drawing a 250dp picture
///   over a form that no longer fits under it.
///
/// That arithmetic, and not a clip, is what answers the short phone. At
/// 390×844 it yields a 250dp photographic plate. At **360×640 it yields
/// [PlateForm.collapsed]** — `640 − 520` is 120, under the 200dp floor — so
/// the picture is dropped and the same wordmark, headline and sentence render
/// on a 96dp band on the ground, which is very nearly the masthead that screen
/// already had. That is the machinery doing its job: the screen where the form
/// already runs to the fold does not spend 250dp on a picture.
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
class EntryPlate extends StatelessWidget {
  const EntryPlate({
    super.key,
    required this.headline,
    required this.supporting,
    this.skinCycle,
  });

  /// The skin cycle, in the plate's top-right. See the note where it is
  /// placed: it lives here so the commit row below can be edge to edge.
  final Widget? skinCycle;

  /// `loginHeadline`. Printed by a [TorchDisplayHeadline], which is the same
  /// widget the masthead used and the reason the header landmark a screen
  /// reader jumps to on arrival survives this change.
  final String headline;

  /// `loginSubtitle`. One line of `body` in `ink2` under the headline.
  final String supporting;

  /// The bundled picture. See the note beside it in `pubspec.yaml` for why
  /// this one and why bundled.
  static const String asset = 'assets/images/entry-plate.jpg';

  /// The id the strip light would be lit under, **declared by no route**. It
  /// exists so the widget can ask and be told no, which is the whole of §2
  /// above.
  static const String claimId = 'entry-plate-light';

  /// The mockup's proportion: roughly the top 250 of 844.
  static const double tallest = 250;

  /// The shortest photographic plate the door will accept — **150, against
  /// The Floor's 200, and it is the difference between a picture and none.**
  ///
  /// On The Floor a plate is context above a list of work, so a 150dp strip is
  /// room the work needs. Here the plate IS the screen: the owner chose this
  /// direction out of three *because* the picture is the product's signature,
  /// and a door that silently drops it has not been built.
  ///
  /// The number this replaces was doing real damage and doing it invisibly.
  /// With [ground] at 566 and a 200 floor, a photograph needed a **766dp**
  /// viewport. The owner's phone is 810 and drew one; their browser window was
  /// 749 and did not — and the reasonable conclusion from outside was that the
  /// web build had not been rebuilt. It had. One rule was drawing two
  /// different screens 17dp apart, and 749 is an utterly ordinary laptop
  /// window.
  ///
  /// At 150 the picture survives to a 716dp viewport, and below that the band
  /// is still the honest answer: under 150dp a photograph with type on it is a
  /// smear, not a plate.
  static const double shortest = 150;

  /// What the sign-in form and its commit row need under the plate at 1.0×.
  ///
  /// **566, and it is a measurement rather than a proportion.** The first
  /// number written here was 520 and it was wrong: `entry_plate_test.dart`
  /// rasterises the real screen and measures the foot of the plate to the
  /// foot of the commit action, and that is 566dp in Onest at 390 wide. The
  /// test fails with the number to put here, so this can never drift into a
  /// guess again.
  static const double ground = 566;

  /// How much of [ground] is prose, and therefore grows with the text scale.
  /// The rest is gaps, field chrome and the commit row's own height, which do
  /// not.
  static const double groundProse = 200;

  /// The reserve at a given text scale. Linear in the prose share, which is
  /// the honest approximation: at 2.0× the form below is far taller, the fold
  /// cannot hold both, and the plate collapses rather than pushing the button
  /// off the screen.
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
          ground: groundFor(scale),
          tallest: tallest,
          shortest: shortest,
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
          // THE MARK LEFT, THE SKIN CYCLE RIGHT — 30 September 2026.
          //
          // The cycle used to sit in the commit row, beside the button, which
          // is why the button was not full width. The approved mockup's commit
          // is edge to edge and carries nothing else: *"look at the Sign in
          // and forgot password on this image and do exactly that"*.
          //
          // It moves rather than goes. "Never a screen without the cycle" is a
          // standing rule and a person who cannot read this ground has to be
          // able to change it before they can sign in — so it takes the corner
          // opposite the wordmark, on the band the plate already reserves for
          // exactly this kind of small control.
          //
          // `Flexible`, not a `Spacer` between two fixed children: at 2.0x the
          // wordmark is twice the width it is at 1.0 and this Row overflowed
          // by 124 logical pixels the first time it was written. The cycle is
          // a fixed 44dp target and may not shrink; the mark is type and can.
          topSlot: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Semantics(
                  container: true,
                  child: const EntryBrand(monogram: 24, compact: true),
                ),
              ),
              const SizedBox(width: TiqSpace.s3),
              ?skinCycle,
            ],
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
                SizedBox(height: skin.space.intraBlock),
                Semantics(
                  container: true,
                  child: Text(
                    supporting,
                    style: skin.text.body.style(color: skin.palette.ink2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
