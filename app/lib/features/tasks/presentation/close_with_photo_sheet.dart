import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/camera/photo_capture_service.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/tasks_view.dart';

/// THE CLOSURE GATE — evidence, or the task stays open.
///
/// ```text
///   ────
///   Close this task
///   Replace the shelf talker
///   ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
///   │  ┌───────┐  Photograph the fix so │
///   │  │       │  a manager can see it, │
///   │  └───────┘  not take your word.   │
///   │             Switch the torch on…  │
///   └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
///   Take a photo
///   ┌──────────────────────────────────┐
///   │           Close task             │  ← the one lit object
///   └──────────────────────────────────┘
///   Cancel
/// ```
///
/// ## Why it is a gate and not a warning
///
/// The backend refuses a closure without a photo, so the button says so
/// **before** the press rather than failing after it: `Close task` is disabled
/// with a `blockedReason` naming what is missing, and it is disabled rather
/// than hidden so the reason is visible. Until #41 this uploaded a 1×1
/// transparent placeholder, which meant "photo-verified closure" verified
/// nothing.
///
/// ## The one amber
///
/// A sheet is an untabbed route, and the nav's tab beneath it has already gone
/// out, so Night's two grants are both the sheet's. It spends one: `Close
/// task` at rung 1. Day and Veld spend their single grant on the same block.
/// The pre-capture card is a 2px `edgeControl` outline and a drawing; nothing
/// else on this sheet asks for light.
///
/// ## What is not built, and why
///
/// * **The dark-frame measurement.** The spec's `Dark frame — mean brightness
///   11%` needs the photo's mean luma. Computing it here means decoding the
///   full image on the UI isolate of a phone that has just taken it; the audit
///   pipeline computes it server-side and the console does not receive it.
///   The state is designed and unbuilt rather than guessed at.
/// * **Hold and send later.** The console has no outbox — held work is the
///   agent app's queue. A failed upload keeps the photo and the sheet, which
///   is the honest console answer: nothing is lost and nothing is promised.
Future<CapturedPhoto?> showCloseWithPhotoSheet(
  BuildContext context, {
  required TaskRow task,
}) {
  return showTorchSheet<CapturedPhoto>(
    context,
    builder: (_) => _CloseWithPhotoSheet(task: task),
  );
}

class _CloseWithPhotoSheet extends ConsumerStatefulWidget {
  const _CloseWithPhotoSheet({required this.task});

  final TaskRow task;

  @override
  ConsumerState<_CloseWithPhotoSheet> createState() =>
      _CloseWithPhotoSheetState();
}

class _CloseWithPhotoSheetState extends ConsumerState<_CloseWithPhotoSheet> {
  static const String closeClaimId = 'close-task';

  CapturedPhoto? _photo;
  bool _capturing = false;
  TorchErrorMessage? _failure;

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() {
      _capturing = true;
      _failure = null;
    });
    try {
      final photo = await ref
          .read(photoCaptureServiceProvider)
          .capture(PhotoSource.camera, geotag: true);
      if (!mounted) return;
      // Backing out of the camera is a normal outcome, not an error, and it
      // keeps whatever photo was already taken.
      setState(() {
        _capturing = false;
        if (photo != null) _photo = photo;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _failure = TorchErrorMessage.sanitise(
          error,
          status: error is PhotoTooLargeException ? 413 : null,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final photo = _photo;

    return TorchSheet(
      title: 'Close this task',
      claims: const <TorchClaim>[TorchClaim.primaryCommit(closeClaimId)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // What was supposed to be fixed. The closure is judged against it.
          Text(
            widget.task.requiredFix,
            style: skin.text.body.style(color: p.ink2),
          ),
          const SizedBox(height: TiqSpace.s5),

          if (photo == null)
            const _PreCaptureCard()
          else
            _CapturedStrip(photo: photo),

          const SizedBox(height: TiqSpace.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('take-closure-photo'),
              label: photo == null ? 'Take a photo' : 'Retake',
              busy: _capturing,
              onPressed: _capture,
            ),
          ),

          if (_failure != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            TorchErrorRegion(
              name: 'closure photo',
              child: ErrorState(
                scope: ErrorScope.inline,
                message: _failure!,
                action: _failure!.offersRetry
                    ? TorchTertiaryButton(
                        label: 'Try again',
                        onPressed: _capture,
                      )
                    : null,
              ),
            ),
          ],

          const SizedBox(height: TiqSpace.s6),
          TorchPrimaryButton(
            key: const ValueKey<String>('confirm-closure'),
            claimId: closeClaimId,
            label: 'Close task',
            // No photo, no closure — and the button says which, above itself,
            // as a live region.
            blockedReason: photo == null ? 'A photo is required.' : null,
            onPressed: photo == null
                ? null
                : () => Navigator.of(context).pop(photo),
          ),
          const SizedBox(height: TiqSpace.s3),
          // Cancel takes the bottom: the bottom-most control under a
          // travelling thumb is never the one that commits.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('cancel-closure'),
              label: 'Cancel',
              // Cancelling leaves the task open, which is the correct outcome.
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pre-capture card: a framing drawing, the instruction, and the reminder
/// that matters in a back aisle during Stage 6.
///
/// Phase 1 ships no in-app preview — `Take a photo` hands off to the OS camera
/// — and this card does not pretend otherwise.
class _PreCaptureCard extends StatelessWidget {
  const _PreCaptureCard();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.radii.control),
        border: Border.all(color: p.edgeControl, width: skin.depth.borderWidth),
      ),
      padding: const EdgeInsets.all(TiqSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size.square(48),
              painter: _FramingPainter(colour: p.ink3),
            ),
          ),
          const SizedBox(width: TiqSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Photograph the fix so a manager can see it, not take your '
                  'word for it.',
                  style: skin.text.body.style(color: p.ink2),
                ),
                const SizedBox(height: TiqSpace.s2),
                Text(
                  'Switch the phone torch on in a dark aisle.',
                  style: skin.text.meta.style(color: p.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 2px-stroke schematic of a shelf in a frame. Drawn, not an asset: it is
/// two rectangles and three lines, and a 40 kB illustration for that is
/// forty kilobytes of a prepaid bundle.
class _FramingPainter extends CustomPainter {
  const _FramingPainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final frame = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRect(frame, stroke);
    for (var i = 1; i <= 3; i++) {
      final y = frame.top + frame.height * i / 4;
      canvas.drawLine(
        Offset(frame.left + 6, y),
        Offset(frame.right - 6, y),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_FramingPainter old) => old.colour != colour;
}

/// What came back: a 72dp thumbnail, the capture time, and whether the phone
/// knew where it was.
class _CapturedStrip extends StatelessWidget {
  const _CapturedStrip({required this.photo});

  final CapturedPhoto photo;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final hasFix = photo.gpsTag.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(skin.radii.control),
              child: Image.memory(
                _bytesOf(photo.dataUrl),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(skin.radii.control),
                    border: Border.all(
                      color: p.edgeStructure,
                      width: skin.depth.borderWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: TiqSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _stamp(photo.capturedAt),
                style: skin.text.monoIdent.style(color: p.ink3),
              ),
              const SizedBox(height: TiqSpace.s2),
              if (hasFix)
                Text(
                  _place(context, photo.gpsTag),
                  style: skin.text.monoIdent.style(color: p.ink3),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const FlagChip(kind: FlagKind.noGps),
                    const SizedBox(width: TiqSpace.s2),
                    Flexible(
                      child: Text(
                        'The closure will record without one.',
                        style: skin.text.meta.style(color: p.ink3),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The raw bytes behind a `data:` URL. The picker hands back base64 and the
  /// thumbnail is the one place the console shows the photo it is about to
  /// send, so there is nothing to fetch and nothing to cache.
  static Uint8List _bytesOf(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return Uint8List(0);
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } on FormatException {
      return Uint8List(0);
    }
  }

  /// Through the one formatter, like every other figure: an Afrikaans phone
  /// gets a comma decimal mark and the grouping the locale declares.
  static String _place(BuildContext context, Map<String, dynamic> tag) {
    final numbers = TiqNumber.of(context);
    final lat = tag['lat'] as num?;
    final lng = tag['lng'] as num?;
    if (lat == null || lng == null) return '';
    return '${numbers.format(lat, decimals: 5)}, '
        '${numbers.format(lng, decimals: 5)}';
  }

  static String _stamp(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Captured $hh:$mm';
  }
}
