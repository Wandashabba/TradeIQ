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
  });

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

  /// What the sign-in form and its commit row need under the plate at 1.0×,
  /// measured by `entry_plate_test.dart`.
  static const double ground = 520;

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
          image: const AssetImage(asset),
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
          topSlot: const EntryBrand(monogram: 24, compact: true),
          hero: SizedBox(
            width: text < 0 ? 0 : text,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TorchDisplayHeadline(headline),
                SizedBox(height: skin.space.intraBlock),
                Text(
                  supporting,
                  style: skin.text.body.style(color: skin.palette.ink2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
