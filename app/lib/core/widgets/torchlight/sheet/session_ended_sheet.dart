import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/buttons.dart';
import '../mark/tiq_mark.dart';
import 'proof_block.dart';
import 'torch_sheet.dart';

/// SIGNED OUT — #380/#392. **A state, not an error.**
///
/// ```dart
/// showTorchSheet<bool>(
///   context,
///   dismissible: false,
///   builder: (context) => SessionEndedSheet(
///     proof: [
///       ProofLine(text: '6 of 9 sections captured'),
///       ProofLine(text: '3 photos held on this phone'),
///     ],
///   ),
/// );
/// ```
///
/// ## Why it is a sheet and not a full-screen state
///
/// Because the held work has to stay **visible behind it**. The 72% scrim is
/// what makes that possible, which is why the assistant surface's 88% lost:
/// the sheet delivers the proof block *and* the screen it is about, and the
/// combination is the reassurance. A full-screen takeover says "everything you
/// were doing is gone"; this says "here is what you were doing, and here is
/// what is still on this phone".
///
/// ## No triangle, no crimson, no "error"
///
/// A token expiring at 14:00 on a Tuesday is a fact about a clock. The drawing
/// is `edgeControl`, the headline is plain, and the body names the work's
/// safety before anything else. It is announced **politely** to a screen
/// reader rather than as an alert, because it is not an emergency, and its
/// proof block is a focusable list so a reader can walk her own held work item
/// by item.
///
/// ## Non-dismissible on first appearance, then a line that stays
///
/// The first appearance swallows the scrim and the back gesture — there is a
/// decision to make. After "Not now", [SessionHeldLine] sits under every
/// header until it is resolved: 44dp, a square, a count and a way back in. A
/// sign-out that could be dismissed and forgotten is a phone full of work
/// nobody sends.
class SessionEndedSheet extends StatelessWidget {
  const SessionEndedSheet({
    super.key,
    required this.proof,
    this.title = 'You have been signed out',
    this.body,
    this.signInLabel = 'Sign in to send them',
    this.notNowLabel = 'Not now',
    this.busy = false,
    this.onSignIn,
    this.onNotNow,
  });

  /// The same countable proof block the decision sheet uses. Not a ghosted
  /// screenshot of the screen behind it: that was a full-screen `saveLayer`
  /// rendering its own reassurance at 2.84:1.
  final List<ProofLine> proof;

  final String title;

  /// Defaults to a sentence built from the proof block's own length, so the
  /// number in the body and the number in the block can never disagree.
  final String? body;

  final String signInLabel;
  final String notNowLabel;
  final bool busy;

  final VoidCallback? onSignIn;
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchSheet(
      title: title,
      subtitle:
          body ??
          'Everything you captured is still on this phone. '
              'It sends itself when you sign in.',
      claims: <TorchClaim>[TorchPrimaryButton.claim('session-sign-in')],
      // Announced politely — no alert role. It is not an emergency.
      semanticsLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ProofBlock(
            lines: proof,
            semanticsLabel: 'What is held on this phone',
          ),
          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            label: signInLabel,
            claimId: 'session-sign-in',
            busy: busy,
            onPressed: busy
                ? null
                : () {
                    onSignIn?.call();
                    Navigator.of(context).pop(true);
                  },
          ),
          const SizedBox(height: TiqSpace.s3),
          TorchSecondaryButton(
            label: notNowLabel,
            onPressed: busy
                ? null
                : () {
                    onNotNow?.call();
                    Navigator.of(context).pop(false);
                  },
          ),
        ],
      ),
    );
  }
}

/// THE LINE THAT STAYS, after "Not now".
///
/// 44dp under every header until the session is resolved. A square, a count
/// and a way back in — Oatmeal, never crimson: being signed out with held work
/// is not a fault, it is a state with one action attached.
class SessionHeldLine extends StatelessWidget {
  const SessionHeldLine({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  /// "6 sections and 3 photos are waiting to send."
  final String message;

  /// "Sign in".
  final String actionLabel;

  final VoidCallback onPressed;

  /// 44 on Night and Day, 64 in Veld.
  static double heightFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? 64 : 44;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return Semantics(
      container: true,
      child: Container(
        constraints: BoxConstraints(minHeight: heightFor(skin)),
        decoration: BoxDecoration(
          color: p.well,
          border: Border(
            bottom: BorderSide(
              color: p.edgeStructure,
              width: skin.depth.borderWidth,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: skin.space.gutter,
          vertical: TiqSpace.s2,
        ),
        child: Row(
          children: <Widget>[
            TiqMark(
              shape: MarkShape.heldSquare,
              color: p.ink2,
              size: MarkScale.glyph(context, 12),
            ),
            const SizedBox(width: TiqSpace.s3),
            Expanded(
              child: Text(
                message,
                style: skin.text.meta.style(color: p.ink2),
              ),
            ),
            const SizedBox(width: TiqSpace.s3),
            TorchTertiaryButton(label: actionLabel, onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}
