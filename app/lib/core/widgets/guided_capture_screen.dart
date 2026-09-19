import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../camera/photo_capture_service.dart';
import '../camera/photo_exposure.dart';
import '../design/torch_scope.dart';
import '../theme/torchlight/agent_skin.dart';
import '../theme/torchlight/tiq_skin.dart';
import 'torchlight/button/buttons.dart';
import 'torchlight/chrome/chrome.dart';
import 'torchlight/marks.dart';
import 'torchlight/row/row.dart';
import 'torchlight/skin_controls.dart';
import 'torchlight/state.dart';

/// PHOTO CAPTURE — PHASE 1.
///
/// A pre-capture framing card, the OS camera, and a review step. **There is no
/// in-app viewfinder and this screen does not pretend there is** — the
/// Phase-2 camera is #405 and is deliberately out of scope, so the honest
/// shape is: tell the agent what to shoot and to switch the torch on, hand
/// off to `image_picker`, and then show them what came back while it can
/// still be re-taken.
///
/// ```text
///   Stock & availability                         ✕
///   One photo
///   ┌───────────────────────────────────────────┐
///   │ ┌─      ─┐                                │
///   │ │        │  Stand back far enough to get  │
///   │ └─      ─┘  the whole bay.                │
///   └───────────────────────────────────────────┘
///   ■ Aisle dark? Switch your phone torch on.
///   Your photo is stamped with the time and where you are.
///   [ ☾ ] [            Open camera             ]
///         [             Cancel                 ]
/// ```
///
/// ## The dark frame (the reason the review step exists)
///
/// A shelf photographed with the aisle lights off is a frame nobody can read.
/// The two easy answers are both dishonest: keeping it silently means a
/// manager finds out a week later, and dropping it silently means the agent
/// walks out of the shop believing they captured something. So the returned
/// bytes are *measured* ([meanLuma]) and anything under 18% mean luma comes
/// back to the review step **edged and questioned** — never auto-rejected,
/// because during Stage 6 it may be the only obtainable evidence.
///
/// ## Amber
///
/// An untabbed route with no nav, so the content has two grants in Night and
/// this screen spends exactly one of them in every phase: `Open camera` while
/// framing, `Use it` in review. A busy primary keeps its claim — the light
/// does not go out while the camera is opening.
class GuidedCaptureScreen extends ConsumerStatefulWidget {
  const GuidedCaptureScreen({
    super.key,
    required this.label,
    required this.hint,
    this.geotag = false,
    this.allowGallery = true,
  });

  /// The section this evidence belongs to — the screen's title.
  final String label;

  /// One line telling the agent how to frame the shot.
  final String hint;

  /// Tag the photo with where the device is as it is taken (#310). See
  /// [PhotoCaptureService.capture].
  final bool geotag;

  /// Whether the gallery is offered beside the camera.
  ///
  /// True almost everywhere, and deliberately: a cracked camera in a dark
  /// aisle still has to be able to file evidence. False for the one capture
  /// where the picture IS the claim — a wrong-pin report's storefront photo
  /// (#386). A gallery image is stamped with the moment it was picked and the
  /// position at that moment, so a screenshot chosen at home arrives with a
  /// fresh time and a home tag that agree with the claimed position perfectly.
  /// The server refuses one for that section; this is the same rule where the
  /// agent can see it, so the refusal is a button that is not there rather
  /// than an error after the work.
  final bool allowGallery;

  /// The primary's claim id. One id across both phases: only one primary is
  /// ever on screen, and a census failure names the phase.
  static const String captureClaimId = 'capture-primary';

  @override
  ConsumerState<GuidedCaptureScreen> createState() =>
      _GuidedCaptureScreenState();
}

class _GuidedCaptureScreenState extends ConsumerState<GuidedCaptureScreen> {
  TorchErrorMessage? _error;
  bool _busy = false;

  /// The frame waiting to be accepted or re-taken. Null means the agent is
  /// still framing.
  CapturedPhoto? _review;

  Future<void> _capture(PhotoSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      final photo = await ref
          .read(photoCaptureServiceProvider)
          .capture(source, geotag: widget.geotag);
      // A cancel is a normal outcome, not a failure — stay on the card so the
      // agent can line the shot up again rather than being thrown all the way
      // back out.
      if (photo == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      // Measured here and not in the service: the service runs on the capture
      // path, where a full-size decode is an OOM on a 2 GB handset, and this
      // is the one moment the answer is actually needed.
      final luma = await ref.read(photoExposureProvider)(photo.dataUrl);
      if (!mounted) return;
      setState(() {
        _review = photo.withMeanLuma(luma);
        _busy = false;
      });
    } on PhotoTooLargeException catch (e) {
      if (mounted) {
        setState(() {
          _error = TorchErrorMessage(
            kind: TorchErrorKind.rejected,
            headline: l10n.captureErrorChip,
            body: e.toString(),
            offersRetry: false,
          );
          _busy = false;
        });
      }
    } catch (e) {
      // Denied camera permission lands here. Say so — an agent who thinks the
      // button is broken will stop filing evidence.
      if (mounted) {
        setState(() {
          _error = TorchErrorMessage(
            kind: TorchErrorKind.rejected,
            headline: l10n.captureErrorChip,
            body: l10n.captureError('$e'),
            offersRetry: false,
          );
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      TorchlightRoute(child: _review == null ? _framing() : _reviewing());

  /// PHASE 1 — the framing card. What to shoot, and the torch.
  Widget _framing() {
    final l10n = context.l10n;
    final skin = context.skin;

    return _CaptureFrame(
      phase: 'framing',
      title: widget.label,
      facts: <String>[l10n.photoFieldAdd],
      busy: _busy,
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('guided-capture'),
        claimId: GuidedCaptureScreen.captureClaimId,
        label: l10n.captureButton,
        semanticLabel: l10n.captureOpenCameraSemantics,
        icon: Icons.photo_camera_outlined,
        busy: _busy,
        onPressed: _busy ? null : () => _capture(PhotoSource.camera),
      ),
      secondary: widget.allowGallery
          ? TorchSecondaryButton(
              key: const ValueKey<String>('guided-gallery'),
              // Gallery is not a convenience — a cracked camera in a dark aisle
              // still has to be able to file evidence. The one exception is
              // [GuidedCaptureScreen.allowGallery]; see it for why.
              label: l10n.captureGalleryButton,
              icon: Icons.photo_library_outlined,
              onPressed: _busy ? null : () => _capture(PhotoSource.gallery),
            )
          : null,
      onClose: () => Navigator.of(context).pop(),
      closeLabel: l10n.captureCancelTooltip,
      children: <Widget>[
        _FramingCard(hint: widget.hint),
        const SizedBox(height: TiqSpace.s4),
        // The torch row. TORCH is never an amber block: calling a torch
        // control a light source is a pun, not a rule.
        Semantics(
          liveRegion: true,
          child: Row(
            key: const ValueKey<String>('torch-hint'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const RowMarkTile(mark: RowMark.square),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Text(
                  l10n.captureTorchHint,
                  style: skin.text.label.style(color: skin.palette.ink2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TiqSpace.s4),
        Text(
          l10n.captureStampNote,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        ?_errorRegion(),
      ],
    );
  }

  /// PHASE 2 — the review step. What actually came back.
  Widget _reviewing() {
    final l10n = context.l10n;
    final skin = context.skin;
    final photo = _review!;
    final dark = photo.isUnderexposed;

    return _CaptureFrame(
      phase: dark ? 'review-dark' : 'review',
      title: l10n.captureReviewTitle,
      facts: <String>[widget.label],
      busy: false,
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('guided-use-it'),
        claimId: GuidedCaptureScreen.captureClaimId,
        label: l10n.captureUseIt,
        onPressed: () => Navigator.of(context).pop(photo),
      ),
      secondary: TorchSecondaryButton(
        key: const ValueKey<String>('guided-retake'),
        // Retake re-opens the camera and the current frame survives until a
        // new one lands, so a backed-out retake loses nothing.
        label: l10n.photoFieldRetake,
        onPressed: () => _capture(PhotoSource.camera),
      ),
      onClose: () => Navigator.of(context).pop(),
      closeLabel: l10n.captureCancelTooltip,
      children: <Widget>[
        _ReviewFrame(photo: photo),
        if (dark) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Semantics(
            liveRegion: true,
            label: l10n.captureDarkSemantics,
            excludeSemantics: true,
            child: Row(
              key: const ValueKey<String>('photo-dark'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SeverityMark(kind: SeverityMarkKind.watch),
                const SizedBox(width: TiqSpace.s2),
                Expanded(
                  child: Text(
                    l10n.captureDarkCaption,
                    style: skin.text.label.style(color: skin.palette.ink2),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s4),
        // The geotag is stated, never hidden: it is what places a stock count
        // for the fraud module, and its absence is a fact about the photo.
        Text(
          l10n.capturePhotoMeta(
            _hhmm(photo.capturedAt),
            photo.gpsTag.isEmpty ? l10n.captureNoGeotag : l10n.captureGeotagged,
          ),
          key: const ValueKey<String>('photo-meta'),
          style: skin.text.monoIdent.style(color: skin.palette.ink2),
        ),
        ?_errorRegion(),
      ],
    );
  }

  Widget? _errorRegion() {
    final error = _error;
    if (error == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: TiqSpace.s4),
      child: ErrorState(
        key: const ValueKey<String>('guided-error'),
        message: error,
        scope: ErrorScope.inline,
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// The frame both phases wear: one shell, one thumb zone, one lit primary.
class _CaptureFrame extends StatelessWidget {
  const _CaptureFrame({
    required this.phase,
    required this.title,
    required this.facts,
    required this.busy,
    required this.primary,
    required this.secondary,
    required this.onClose,
    required this.closeLabel,
    required this.children,
  });

  final String phase;
  final String title;
  final List<String> facts;
  final bool busy;
  final Widget primary;
  final Widget? secondary;
  final VoidCallback onClose;
  final String closeLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      // One grant of the two an untabbed route has, in every phase. A busy
      // primary keeps it: the light does not blink while the camera opens.
      claims: const <TorchClaim>[
        TorchClaim.primaryCommit(GuidedCaptureScreen.captureClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(
          title: title,
          facts: facts,
          back: TorchIconButton(
            key: const ValueKey<String>('guided-close'),
            icon: Icons.close,
            // Names the destination, never "Close".
            semanticLabel: closeLabel,
            onPressed: onClose,
          ),
        ),
        skinCycle: const AgentSkinCycle(),
        primary: primary,
        secondary: secondary,
        children: children,
      ),
    );
  }
}

/// The framing card: a drawn bay with corner brackets, and the line that
/// carries the whole instruction.
class _FramingCard extends StatelessWidget {
  const _FramingCard({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final veld = skin.mode == SkinMode.veld;

    return Container(
      key: const ValueKey<String>('framing-card'),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The drawing carries nothing a reader needs: the framing line is
          // the whole instruction, so the picture is excluded outright.
          ExcludeSemantics(
            child: SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                key: const ValueKey<String>('framing-brackets'),
                painter: _FramingBracketPainter(
                  colour: skin.palette.edgeControl,
                  stroke: veld ? 3 : 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: TiqSpace.s4),
          Expanded(
            child: Text(
              hint,
              style: skin.text.body.style(color: skin.palette.ink1),
            ),
          ),
        ],
      ),
    );
  }
}

/// What came back, at the size the phone can actually decode.
class _ReviewFrame extends StatelessWidget {
  const _ReviewFrame({required this.photo});

  final CapturedPhoto photo;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final dark = photo.isUnderexposed;
    final width = MediaQuery.sizeOf(context).width - skin.space.gutter * 2;
    final ratio = MediaQuery.devicePixelRatioOf(context);

    Widget failed() => Container(
      key: const ValueKey<String>('photo-decode-failed'),
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: skin.palette.well,
        borderRadius: BorderRadius.circular(skin.radii.control),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
      child: Text(
        l10n.captureNoCamera,
        style: skin.text.body.style(color: skin.palette.ink2),
      ),
    );

    final bytes = _bytesOf(photo.dataUrl);
    if (bytes == null) return failed();

    return Semantics(
      label: l10n.capturePhotoSemantics(_hhmm(photo.capturedAt)),
      image: true,
      excludeSemantics: true,
      child: DecoratedBox(
        key: const ValueKey<String>('photo-preview'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(skin.radii.control),
          border: Border.all(
            // Underexposed takes the comparison edge and the caption beneath;
            // it is a question, not a verdict, so it is never the severity
            // bar's crimson.
            color: dark ? skin.palette.comparison : skin.palette.edgeControl,
            width: dark ? 2 : skin.depth.borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(skin.radii.control),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            // A 12 MP shelf photo decoded full-size is an OOM on a 2 GB
            // handset. Decode at the size it is actually drawn at.
            cacheWidth: (width * ratio).round().clamp(1, 4096),
            errorBuilder: (context, error, stack) => failed(),
          ),
        ),
      ),
    );
  }

  static Uint8List? _bytesOf(String dataUrl) {
    if (!dataUrl.startsWith('data:')) return null;
    final comma = dataUrl.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Four L-shaped corner brackets — the framing guide the agent lines the real
/// shot up inside. Inset by half the stroke so no edge is clipped.
class _FramingBracketPainter extends CustomPainter {
  const _FramingBracketPainter({required this.colour, required this.stroke});

  final Color colour;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = colour
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final len = size.shortestSide * 0.35;
    final o = stroke / 2;
    final w = size.width - o;
    final h = size.height - o;

    canvas.drawPath(
      Path()
        ..moveTo(o, o + len)
        ..lineTo(o, o)
        ..lineTo(o + len, o),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, o)
        ..lineTo(w, o)
        ..lineTo(w, o + len),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(o, h - len)
        ..lineTo(o, h)
        ..lineTo(o + len, h),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, h)
        ..lineTo(w, h)
        ..lineTo(w, h - len),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _FramingBracketPainter old) =>
      old.colour != colour || old.stroke != stroke;
}
