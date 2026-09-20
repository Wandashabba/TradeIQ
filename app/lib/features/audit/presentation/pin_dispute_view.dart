import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/camera/photo_capture_service.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/guided_capture_screen.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/presentation/today_screen.dart' show displayFor;
import '../../outlets/data/outlets_repository.dart';
import '../data/visits_repository.dart';
import 'audit_shell_screen.dart';

/// Opens the storefront capture and returns the photo, or null on a cancel.
///
/// A seam rather than a direct push so a widget test can hand the screen a
/// photo without driving the OS camera — the same reason
/// [photoCaptureServiceProvider] exists one layer down.
typedef StorefrontPhotoPicker =
    Future<CapturedPhoto?> Function(BuildContext context);

final storefrontPhotoPickerProvider = Provider<StorefrontPhotoPicker>(
  (ref) => (context) {
    final l10n = context.l10n;
    return Navigator.of(context).push<CapturedPhoto>(
      agentSectionRoute<CapturedPhoto>(
        GuidedCaptureScreen(
          label: l10n.pinDisputePhotoLabel,
          hint: l10n.pinDisputePhotoHint,
          // Evidence: where the phone was at the shutter is half of what makes
          // a storefront photo worth anything to the manager reading it.
          geotag: true,
          // ...and the other half is that the shutter was pressed HERE. A
          // gallery pick carries the time it was picked and the position at
          // that moment, so a Street View screenshot chosen at home would
          // arrive with a fresh time and a home tag agreeing exactly with the
          // claimed position. The server refuses one for this section
          // (photos.service); the button is gone so nobody spends the work
          // first.
          allowGallery: false,
        ),
      ),
    );
  },
);

/// What the agent files with "the pin is wrong".
typedef PinDisputeFiling = ({String? note, CapturedPhoto? photo});

/// "THE PIN IS WRONG" (#386) — the report, and the visit it lets start.
///
/// This is an override on the control that exists to stop check-in fraud, so
/// the screen says so in plain words before the agent commits: the visit
/// starts **outside the fence and stays flagged**, the manager sees where the
/// phone was and how far that is from the pin, and the agent cannot clear the
/// flag. What it carries is listed as evidence, not as a form: the distance
/// and the position are already recorded; only the note and the photo are the
/// agent's to add, and both are optional because the agent at the door of a
/// shop the app says is 8 km away has already told us the one thing that
/// matters.
///
/// One primary, in the thumb zone, and it is this route's one amber object in
/// every skin. The way back is the ghost above it.
class PinDisputeView extends ConsumerStatefulWidget {
  const PinDisputeView({
    super.key,
    required this.outlet,
    required this.failure,
    required this.onFile,
    required this.onCancel,
    this.error,
  });

  final Outlet outlet;

  /// The failed check-in being disputed: its distance and its position.
  final CheckInGeofenceFailed failure;

  /// Files the report. The screen stays busy until it completes.
  final Future<void> Function(PinDisputeFiling filing) onFile;

  final VoidCallback onCancel;

  /// Why the last attempt to file failed, if it did.
  final String? error;

  @override
  ConsumerState<PinDisputeView> createState() => _PinDisputeViewState();
}

class _PinDisputeViewState extends ConsumerState<PinDisputeView> {
  final _note = TextEditingController();
  CapturedPhoto? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final photo = await ref.read(storefrontPhotoPickerProvider)(context);
    if (!mounted || photo == null) return;
    setState(() => _photo = photo);
  }

  Future<void> _file() async {
    setState(() => _busy = true);
    try {
      await widget.onFile((note: _note.text, photo: _photo));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final metres = widget.failure.distanceMeters.round();
    final photo = _photo;
    final error = widget.error;

    return VisitFrame(
      phase: 'pin-dispute',
      title: widget.outlet.name,
      facts: <String>[widget.outlet.code],
      showSyncChip: false,
      claimSubmit: true,
      claimId: AuditShellScreen.pinDisputeClaimId,
      submit: TorchPrimaryButton(
        key: const ValueKey<String>('pin-dispute-submit'),
        claimId: AuditShellScreen.pinDisputeClaimId,
        label: l10n.pinDisputeSubmit,
        busy: _busy,
        onPressed: _file,
      ),
      secondary: TorchSecondaryButton(
        key: const ValueKey<String>('pin-dispute-back'),
        label: l10n.pinDisputeBack,
        // Disabled while the visit is being written, by the same blocker the
        // busy primary already shows — see [TorchSecondaryButton.blockedReason].
        onPressed: _busy ? null : widget.onCancel,
      ),
      children: <Widget>[
        Eyebrow(l10n.pinDisputeEyebrow),
        const SizedBox(height: TiqSpace.s3),
        Semantics(
          header: true,
          child: Text(
            l10n.pinDisputeTitle,
            style: displayFor(
              context,
              l10n.pinDisputeTitle,
            ).style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        _Evidence(metres: metres, photo: photo != null),
        const SizedBox(height: TiqSpace.s5),
        Text(
          l10n.pinDisputeExplain,
          key: const ValueKey<String>('pin-dispute-explain'),
          style: skin.text.body.style(color: skin.palette.ink2),
        ),
        const SizedBox(height: TiqSpace.s6),
        TorchTextField(
          key: const ValueKey<String>('pin-dispute-note'),
          label: l10n.pinDisputeNoteLabel,
          hint: l10n.pinDisputeNoteHint,
          controller: _note,
          enabled: !_busy,
          maximumLength: pinDisputeNoteMaxLength,
          minLines: 2,
          maximumLines: 5,
        ),
        const SizedBox(height: TiqSpace.s5),
        if (photo != null) ...<Widget>[
          Text(
            l10n.pinDisputePhotoAdded,
            key: const ValueKey<String>('pin-dispute-photo-added'),
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s2),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('pin-dispute-photo'),
            icon: Icons.photo_camera_outlined,
            label: photo == null
                ? l10n.pinDisputeAddPhoto
                : l10n.pinDisputeRetakePhoto,
            onPressed: _busy ? null : _takePhoto,
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          Text(
            l10n.pinDisputeFailed(error),
            key: const ValueKey<String>('pin-dispute-error'),
            style: skin.text.body.style(color: skin.palette.ink1),
          ),
        ],
      ],
    );
  }
}

/// What goes with the report whether or not the agent adds anything.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.metres, required this.photo});

  final int metres;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(top: TiqSpace.s3),
      child: Text(text, style: skin.text.body.style(color: skin.palette.ink2)),
    );

    return Container(
      key: const ValueKey<String>('pin-dispute-evidence'),
      width: double.infinity,
      padding: const EdgeInsets.all(TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
        boxShadow: skin.depth.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Eyebrow(l10n.pinDisputeEvidenceEyebrow),
          const SizedBox(height: TiqSpace.s3),
          Semantics(
            container: true,
            label: l10n.pinDisputeDistanceSemantics(metres),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FigureSlot(
                  value: metres,
                  role: skin.text.figureL,
                  unit: TiqUnit.worded(l10n.unitMetres),
                  semanticsLabel: l10n.pinDisputeDistanceSemantics(metres),
                ),
                const SizedBox(height: TiqSpace.s1),
                Text(
                  l10n.pinDisputeDistanceLine,
                  style: skin.text.meta.style(color: skin.palette.ink2),
                ),
              ],
            ),
          ),
          line(l10n.pinDisputePositionLine),
          if (photo) line(l10n.pinDisputePhotoLine),
        ],
      ),
    );
  }
}

/// The two flags a visit started this way carries on the hub, and the sheet
/// either of them opens.
///
/// Neutral, never crimson (unify §1.6): out of fence is a measurement and
/// "pin reported" is a claim somebody will review — neither is a verdict. The
/// agent cannot dismiss them; they are facts about this visit.
List<Widget> overrideFlagChips(BuildContext context, CheckInOverridden result) {
  final l10n = context.l10n;
  final metres = result.distanceMeters.round();
  void explain() => showTorchSheet<void>(
    context,
    builder: (sheetContext) => TorchSheet(
      title: sheetContext.l10n.visitFlagSheetTitle,
      closeLabel: sheetContext.l10n.sheetClose,
      child: Text(
        sheetContext.l10n.visitFlagSheetBody(metres),
        key: const ValueKey<String>('visit-flag-sheet-body'),
        style: sheetContext.skin.text.body.style(
          color: sheetContext.skin.palette.ink2,
        ),
      ),
    ),
  );
  return <Widget>[
    FlagChip(
      key: const ValueKey<String>('flag-out-of-fence'),
      kind: FlagKind.outOfFence,
      label: l10n.visitFlagOutOfFence,
      detail: l10n.visitFlagMetres(metres),
      semanticsLabel: l10n.visitFlagOutOfFenceSemantics(metres),
      onTap: explain,
    ),
    FlagChip(
      key: const ValueKey<String>('flag-pin-reported'),
      kind: FlagKind.forReview,
      label: l10n.visitFlagPinReported,
      semanticsLabel: l10n.visitFlagPinReportedSemantics,
      onTap: explain,
    ),
  ];
}
