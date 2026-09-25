import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../location/location_sharing.dart';
import '../theme/torchlight/tiq_skin.dart';
import 'torchlight/button/buttons.dart';
import 'torchlight/marks.dart';
import 'torchlight/row/row.dart';
import 'torchlight/sheet.dart';

/// Location sharing, told to the agent in words (#153 T1, POPIA risk 1).
///
/// Three faces, and nothing at all for anyone who is not a field agent or
/// before the settings are known:
///
/// - **The notice**, until the agent answers it: what is shared, with whom,
///   when, and when it stops — with a clear yes and a clear no. No ping is sent
///   before a yes.
/// - **The indicator**, on every agent screen for as long as sharing is on. It
///   is not dismissible, because "am I being located right now?" must always
///   have a visible answer. Tapping it offers to stop.
/// - **A quiet "not shared" line** after a no, so the agent can change their
///   mind without hunting for a setting.
///
/// ## Torchlight, and not one word changed
///
/// This is a **restyle**. Every sentence, every key and every branch is the
/// one that was here: POPIA copy is not the kind of thing a design migration
/// gets to improve, and a consent notice whose wording drifts is a consent
/// notice nobody can point at afterwards.
///
/// What did change is what it is built out of, and how much of it is on
/// screen before the agent asks. All three faces are the kit's banner — a
/// standalone soft row at COMPACT density, which is what the Offline / held
/// banner declares and what a standing statement under a header is. The
/// notice is that same banner with the full copy and both answers folded
/// inside it until it is opened; see [_LocationNotice] for why. The buttons
/// are the button family, and the stop confirmation is a [ConfirmSheet]
/// rather than an `AlertDialog`, because unify §1.7 deleted the dialog
/// outright — one modal container, one set of insets, one answer to what
/// happens to the amber underneath.
///
/// **Amber:** the notice's yes is a genuine commit and asks `TorchScope` for
/// the light like every other primary. On the un-migrated screens this banner
/// still appears on there is no scope to ask, so it renders its ink form — it
/// can never light itself on a screen that did not count it.
class LocationSharingBanner extends ConsumerWidget {
  const LocationSharingBanner({super.key, this.inset = true});

  /// Whether the banner brings its own side gutter. The legacy scaffold puts
  /// it above a body with no padding, so it does; a Torchlight shell's
  /// children are already inside the gutter, so there it must not.
  final bool inset;

  /// The notice's "I understand, share my location".
  static const String consentClaimId = 'location-consent';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(locationSharingControllerProvider);
    final settings = s.settings;
    if (!s.isAgent || settings == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final skin = context.skin;
    final controller = ref.read(locationSharingControllerProvider.notifier);

    final Widget child;
    if (s.needsNotice || s.reconsidering) {
      child = _LocationNotice(
        minutes: (settings.intervalSeconds / 60).round().clamp(1, 60),
        onAcknowledge: controller.acknowledge,
        onDecline: s.reconsidering
            ? controller.cancelReconsider
            : controller.decline,
      );
    } else if (s.acknowledged) {
      child = SoftRow(
        key: const ValueKey<String>('location-sharing-indicator'),
        form: SoftRowForm.standalone,
        // COMPACT, and the reason line at `meta` rather than `subtitle`: this
        // is the kit's banner, which is a standing statement under the header
        // on every agent screen, not a list row someone is choosing between.
        // At standard density with a `body` second line the two location
        // banners together took 166dp off the top of every screen.
        density: SoftRowDensity.compact,
        title: l10n.locationSharingActiveTitle,
        meta: Text(
          s.noFix
              ? l10n.locationSharingNoFixSubtitle
              : l10n.locationSharingActiveSubtitle,
        ),
        semanticsLabel:
            '${l10n.locationSharingActiveTitle}. '
            '${s.noFix ? l10n.locationSharingNoFixSubtitle : l10n.locationSharingActiveSubtitle}',
        leading: Icon(
          Icons.my_location,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink2,
        ),
        trailing: const SoftRowChevron(),
        onTap: () => _confirmStop(context, controller),
      );
    } else {
      child = SoftRow(
        key: const ValueKey<String>('location-sharing-off'),
        form: SoftRowForm.standalone,
        density: SoftRowDensity.compact,
        title: l10n.locationSharingOffTitle,
        meta: Text(l10n.locationSharingOffSubtitle),
        semanticsLabel:
            '${l10n.locationSharingOffTitle}. '
            '${l10n.locationSharingOffSubtitle}',
        leading: Icon(
          Icons.location_disabled,
          size: MarkScale.glyph(context, 20),
          color: skin.palette.ink3,
        ),
        trailing: const SoftRowChevron(),
        onTap: controller.reconsider,
      );
    }
    // The gap goes BELOW, not above. Above, the last banner sat flush against
    // the first block of the screen's own body — a standing statement welded
    // to the day block, with all the air stacked on the other side of it.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset ? skin.space.gutter : 0,
        0,
        inset ? skin.space.gutter : 0,
        TiqSpace.s4,
      ),
      child: child,
    );
  }

  static Future<void> _confirmStop(
    BuildContext context,
    LocationSharingController controller,
  ) async {
    final l10n = context.l10n;
    final stop = await showTorchSheet<bool>(
      context,
      builder: (context) => ConfirmSheet(
        key: const ValueKey<String>('location-stop-dialog'),
        action: l10n.locationStopTitle,
        consequences: <String>[l10n.locationStopBody],
        commitLabel: l10n.locationStopConfirm,
        cancelLabel: l10n.locationStopCancel,
      ),
    );
    if (stop == true) await controller.decline();
  }
}

/// What is shared, with whom, how often, and when it stops — with a clear yes
/// and a clear no, and no ping sent before the yes.
///
/// ## One component, two forms: the banner and the notice it opens
///
/// Every word of this notice is the one that was here — POPIA copy is not the
/// kind of thing a design pass gets to improve, and a consent notice whose
/// wording drifts is a consent notice nobody can point at afterwards. What
/// changed is how much of it is on screen before the agent asks for it.
///
/// It used to render as a wall: a heading, two full paragraphs, a full-width
/// primary and a text action, all of it unasked, at the top of the body of
/// **every** agent screen, above the route the screen exists to show. On a
/// 360×640 phone it was about a third of the fold and it was the first thing
/// an agent saw every session until they answered it. A notice that large and
/// that early is one people learn to tap past, which is the opposite of
/// informed consent.
///
/// So it takes the kit's banner form by default — a standalone soft row,
/// compact, glyph plus title plus one line — and expands **in place** into the
/// whole notice with both answers. The line it keeps collapsed is the last
/// sentence of the body, word for word: *nothing is sent in the background*.
/// That is the sentence that makes the notice honest, so it is the sentence
/// that stays visible when the rest is folded away.
///
/// Nothing is sent either way until the yes: collapsing is not an answer, and
/// there is no third state where the notice has been dismissed.
class _LocationNotice extends StatefulWidget {
  const _LocationNotice({
    required this.minutes,
    required this.onAcknowledge,
    required this.onDecline,
  });

  final int minutes;
  final VoidCallback onAcknowledge;
  final VoidCallback onDecline;

  @override
  State<_LocationNotice> createState() => _LocationNoticeState();
}

class _LocationNoticeState extends State<_LocationNotice> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return SoftRow(
      key: const ValueKey<String>('location-notice'),
      form: SoftRowForm.standalone,
      density: SoftRowDensity.compact,
      title: l10n.locationNoticeTitle,
      // The honest sentence, in the collapsed form. `meta`, not `subtitle`:
      // the kit's banner puts its second line at meta 12, and this line is a
      // qualification of the title rather than a second claim.
      meta: Text(l10n.locationNoticeSummary),
      leading: Icon(
        Icons.share_location,
        size: MarkScale.glyph(context, 20),
        color: skin.palette.ink1,
      ),
      // The whole banner is the target, which is the kit's banner behaviour
      // and the reason the verb does not need a control of its own: a 48dp
      // labelled expander row under a two-line title and a meta line is
      // another 56dp of a notice that is already the first thing on the
      // screen.
      trailing: const SoftRowChevron(),
      onTap: () => setState(() => _expanded = !_expanded),
      // One utterance, ending in what tapping it does — so a reader hears the
      // title and the honest sentence BEFORE the verb, and the verb is words
      // rather than a chevron nobody can hear.
      semanticsLabel:
          '${l10n.locationNoticeTitle}. ${l10n.locationNoticeSummary}. '
          '${_expanded ? l10n.locationNoticeCollapse : l10n.locationNoticeExpand}',
      actions: _expanded
          ? _NoticeBody(
              minutes: widget.minutes,
              onAcknowledge: widget.onAcknowledge,
              onDecline: widget.onDecline,
            )
          : null,
    );
  }
}

/// The notice itself, once it has been asked for: the full copy and both
/// answers, inside the banner rather than in a sheet on top of it.
class _NoticeBody extends StatelessWidget {
  const _NoticeBody({
    required this.minutes,
    required this.onAcknowledge,
    required this.onDecline,
  });

  final int minutes;
  final VoidCallback onAcknowledge;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Every word, unchanged, including the sentence the collapsed form
        // repeats. The notice an agent agrees to is the whole notice.
        Text(
          l10n.locationNoticeBody(minutes),
          style: skin.text.body.style(color: skin.palette.ink2),
        ),
        SizedBox(height: skin.space.intraBlock),
        TorchPrimaryButton(
          key: const ValueKey<String>('location-notice-acknowledge'),
          claimId: LocationSharingBanner.consentClaimId,
          label: l10n.locationNoticeAcknowledge,
          onPressed: onAcknowledge,
        ),
        const SizedBox(height: TiqSpace.s2),
        TorchTertiaryButton(
          key: const ValueKey<String>('location-notice-decline'),
          label: l10n.locationNoticeDecline,
          onPressed: onDecline,
        ),
      ],
    );
  }
}
