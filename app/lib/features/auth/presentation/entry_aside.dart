import 'package:flutter/material.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';

/// THE PICTURE BESIDE THE FORM, ON A DESK.
///
/// On a phone the door is [EntryPlate]: the picture across the top with the
/// wordmark, headline and sentence on it. A desk is not a tall phone, and
/// stretching that plate across 1400dp gave a letterbox over a 480dp column of
/// fields marooned in the middle — the shape the owner called "mobile login on
/// desktop" on 5 October 2026 and chose **D — the form first** to replace.
///
/// So on a desk the picture moves to its own full-height pane on the right and
/// the three pieces of type move off it onto the ground on the left, where the
/// form is. The picture stops being a masthead and becomes what it always was
/// on The Floor: the territory, beside the work.
///
/// ## Why a second asset rather than the plate's
///
/// `entry-plate.jpg` is 16:9. A pane this shape shows about a quarter of it,
/// and the quarter a cover-fit keeps is the middle — the road, without the sky
/// above it or the town at the end, which are the two things that make the
/// frame read as a route rather than as tarmac. `entry-plate-tall.jpg` is the
/// same scene shot 9:16 for this pane.
///
/// It is made the same way and under the same constraints as every other
/// picture in this product: `gemini-3.1-flash-image`, the model
/// `scripts/generate-place-images.ts` uses, carrying `PLACE_STYLE` from
/// `backend/scripts/places/prompts.ts` verbatim — documentary, 35mm, available
/// light, and **no readable text, no signage, no lettering, no numbers, no
/// brand marks, and no recognisable faces**. That it is generated rather than
/// supplied is the point licensing turns on: the twelve supplied photographs
/// carry `SUPPLIED_RIGHTS` and this does not, which is the first of the three
/// reasons `pubspec.yaml` gives for the door using a generated picture.
///
/// ## No amber, deliberately
///
/// Night allows two lit objects and the door has already spent both: the Sign
/// in commit and the forgot-password underline, declared in `login_screen.dart`
/// and granted at rung 5. [EntryPlate] asks for a third with
/// `claimId = 'entry-plate-light'` and is refused — the id is declared nowhere,
/// so `TorchScope.lit` answers false and the strip light never paints. This
/// pane does not ask at all. A photograph is not a control, and a third lit
/// object on the one screen with two would fail the census for a decoration.
class EntryAside extends StatelessWidget {
  const EntryAside({super.key});

  /// The 9:16 companion to [EntryPlate]'s asset. Bundled, not fetched: a place
  /// image comes off an authed endpoint and `/login` has no token.
  static const String asset = 'assets/images/entry-plate-tall.jpg';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Semantics(
      image: true,
      // The same sentence the plate carries, for the same reason: it says what
      // the picture is without naming a place, because before sign-in there is
      // no territory and inventing one here would be the invention the copy on
      // this screen refuses.
      label:
          'An illustration of a trade route at first light. Generated, '
          'and not a photograph of anywhere in particular.',
      child: DecoratedBox(
        // The ground under the picture, so the pane is the right colour while
        // the asset decodes and in the sliver a cover-fit cannot reach on an
        // unusual aspect. A bare `Container` here would flash white on Night.
        decoration: BoxDecoration(
          color: skin.palette.ground,
          image: const DecorationImage(
            image: AssetImage(asset),
            fit: BoxFit.cover,
            // The road runs up the middle and the town sits at the horizon. A
            // centred cover keeps both at every pane width this frame allows;
            // aligning to an edge loses one or the other.
            alignment: Alignment.center,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
