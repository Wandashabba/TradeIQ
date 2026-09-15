import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../camera/photo_capture_service.dart';
import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';
import 'agent_kit.dart';
import 'console.dart';
import 'glass.dart';

/// A full-screen, guided launch into the OS camera.
///
/// Not a live in-app viewfinder. The recorded user decision (sub-5c plan) is a
/// guided *launch* wrapper: a framing guide plus a big Capture button that hands
/// off to the existing [PhotoCaptureService] (`image_picker`), reusing the
/// offline queue untouched — no new camera dependency. It exists so an agent in
/// a badly-lit aisle can see WHAT to shoot (the section name, a framing hint,
/// and corner brackets) before the camera opens, instead of guessing from a
/// cramped inline tile.
///
/// Pops with the [CapturedPhoto] on a successful capture; pops with `null`
/// (the default) when the agent backs out — a cancel is a normal outcome, not
/// an error, so the caller simply keeps what it had.
class GuidedCaptureScreen extends ConsumerStatefulWidget {
  const GuidedCaptureScreen({
    super.key,
    required this.label,
    required this.hint,
    this.geotag = false,
  });

  /// The section this evidence belongs to — the screen's title.
  final String label;

  /// One line telling the agent how to frame the shot.
  final String hint;

  /// Tag the photo with where the device is as it is taken (#310). See
  /// [PhotoCaptureService.capture].
  final bool geotag;

  @override
  ConsumerState<GuidedCaptureScreen> createState() =>
      _GuidedCaptureScreenState();
}

class _GuidedCaptureScreenState extends ConsumerState<GuidedCaptureScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _capture(PhotoSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await ref
          .read(photoCaptureServiceProvider)
          .capture(source, geotag: widget.geotag);
      // A cancel is a normal outcome, not a failure — stay on the guide so the
      // agent can line the shot up again rather than being thrown all the way
      // back out.
      if (photo == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (mounted) Navigator.of(context).pop(photo);
    } on PhotoTooLargeException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    } catch (e) {
      // Denied camera permission lands here. Say so — an agent who thinks the
      // button is broken will stop filing evidence.
      if (mounted) {
        setState(() {
          _error = context.l10n.captureError('$e');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final glass = colors.glass;
    final brackets = CustomPaint(
      key: const ValueKey('framing-brackets'),
      // A guide graphic, not a viewfinder — brand-coloured
      // corner brackets an agent lines the real shot up inside.
      painter: _FramingBracketPainter(colors.brand),
    );
    final scaffold = Scaffold(
      // Glass: the lit ground shows through a transparent scaffold and bar.
      backgroundColor: glass ? Colors.transparent : colors.plane,
      appBar: AppBar(
        backgroundColor: glass ? Colors.transparent : colors.plane,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('guided-close'),
          padding: glass ? const EdgeInsets.all(5) : null,
          // Glass sets the close mark in a 38px glass chip, as GlassBackChip
          // does — kept an IconButton so its key, tooltip and tap are unchanged.
          icon: glass
              ? GlassPane(
                  kind: GlassKind.pill,
                  radius: 13,
                  shadow: false,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: context.lumen.accentInk,
                    ),
                  ),
                )
              : const Icon(Icons.close, size: 22),
          tooltip: l10n.captureCancelTooltip,
          // Backing out returns null — the caller keeps whatever it had.
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.label,
          overflow: TextOverflow.ellipsis,
          style: glass
              ? LumenGlass.title(size: 20, color: context.lumen.ink)
              : TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: colors.ink1,
                ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.hint,
                style: TextStyle(fontSize: 13, color: colors.ink3, height: 1.4),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    // Glass frames the guide in a panel, so the target reads
                    // as a place on the lit ground rather than loose strokes.
                    child: glass
                        ? GlassPane(
                            radius: LumenGlass.radiusHero,
                            padding: const EdgeInsets.all(14),
                            child: brackets,
                          )
                        : brackets,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                      label: l10n.captureErrorChip,
                      level: StatusLevel.critical,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        key: const ValueKey('guided-error'),
                        style: TextStyle(fontSize: 11.5, color: colors.ink2),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              AgentButton(
                key: const ValueKey('guided-capture'),
                label: l10n.captureButton,
                icon: Icons.photo_camera_outlined,
                onPressed: _busy ? null : () => _capture(PhotoSource.camera),
              ),
              const SizedBox(height: 10),
              // Gallery is not a convenience — a cracked camera in a dark aisle
              // still has to be able to file evidence.
              AgentButton(
                key: const ValueKey('guided-gallery'),
                label: l10n.captureGalleryButton,
                icon: Icons.photo_library_outlined,
                secondary: true,
                onPressed: _busy ? null : () => _capture(PhotoSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    return glass ? LitGround(child: scaffold) : scaffold;
  }
}

/// Four L-shaped corner brackets — the framing guide the agent lines the shot
/// up inside. Inset by half the stroke so no edge is clipped.
class _FramingBracketPainter extends CustomPainter {
  _FramingBracketPainter(this.color);

  final Color color;

  static const double _len = 28;
  static const double _inset = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const o = _inset;
    final w = size.width - _inset;
    final h = size.height - _inset;

    canvas.drawPath(
      Path()
        ..moveTo(o, o + _len)
        ..lineTo(o, o)
        ..lineTo(o + _len, o),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - _len, o)
        ..lineTo(w, o)
        ..lineTo(w, o + _len),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(o, h - _len)
        ..lineTo(o, h)
        ..lineTo(o + _len, h),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - _len, h)
        ..lineTo(w, h)
        ..lineTo(w, h - _len),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _FramingBracketPainter old) =>
      old.color != color;
}
