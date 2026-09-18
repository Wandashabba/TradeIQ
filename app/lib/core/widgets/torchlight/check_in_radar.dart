import 'package:flutter/widgets.dart';

import '../../design/motion_budget.dart';
import '../../design/torch_scope.dart';
import '../../theme/torchlight/tiq_skin.dart';

/// THE LOCATING RADAR — "we are looking for you", not "something is
/// happening".
///
/// Two 1.5px rings expanding 40 → 120dp over 1800ms, half a cycle apart, with
/// a 2px-stroke pin at the centre. A spinner says the app is busy; this says
/// the app is looking for the agent, which is what waiting for a GPS fix
/// actually is.
///
/// ## Why this is an emitter
///
/// unify §1.1 rules that the live pulse means **presence, never progress**,
/// and names the four places it is allowed: a human mid-visit, a tool
/// executing, a person row, and *a GPS fix being sought*. That is rung 6 of
/// the ladder — `TorchClaim.livePulse` — and this widget is the agent
/// surface's only claimant of it. It asks [TorchScope] like every other
/// emitter and paints `chartNeutral` when the answer is no, which is what
/// happens on every light ground: outside, the light source is the sun.
///
/// One ring is lit, never both. The leading ring plus the pin read as one
/// object to the pixel census because the pin sits inside the ring's bounds,
/// and a lit object enclosed by another lit object is not a second light.
///
/// ## Motion
///
/// A local [AnimationController], not the shared application Ticker: this is
/// full-screen, short-lived and exclusive, and it is disposed the instant a
/// result arrives. Under [MotionBudget.still] — reduce-motion, Veld, battery
/// saver — there are no rings at all: a static pin and the headline carry the
/// whole message, and nothing here ever depended on motion to be understood.
class CheckInRadar extends StatefulWidget {
  const CheckInRadar({
    super.key,
    required this.claimId,
    required this.stalled,
    this.diameter = 120,
  });

  /// The id the route declared to [TorchScope] as its live pulse.
  final String claimId;

  /// Past 25 seconds the rings stop and the pin goes to ink-3: the app has
  /// stopped looking, and an animation that keeps running after that is a lie
  /// told at 4 frames a second.
  final bool stalled;

  final double diameter;

  /// The claim a route declares to light this.
  static TorchClaim claim(String id) => TorchClaim.livePulse(id);

  @override
  State<CheckInRadar> createState() => _CheckInRadarState();
}

class _CheckInRadarState extends State<CheckInRadar>
    with SingleTickerProviderStateMixin {
  // Eager, not `late final`: a lazily-created controller would first be built
  // by dispose() on any build that skipped it (reduce-motion), and
  // constructing a Ticker against a dead element throws.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final still = MotionBudget.of(context).still || widget.stalled;
    final lit = TorchScope.lit(context, widget.claimId);

    // `flame700` on the pin rather than flame600: at 40px of 2px stroke the
    // pin is a drawing, and Night's readable amber for a line is the light
    // one (12.92:1 on the ground). The ring is the object; the pin sits
    // inside its bounds and the census counts the pair as one.
    final ringInk = lit ? skin.palette.flame600 : skin.palette.chartNeutral;
    final pinInk = widget.stalled
        ? skin.palette.ink3
        : lit
        ? skin.palette.flame700
        : skin.palette.ink1;

    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }

    final d = widget.diameter;
    return ExcludeSemantics(
      child: SizedBox(
        width: d,
        height: d,
        child: still
            ? CustomPaint(
                painter: _RadarPainter(
                  phases: const <double>[],
                  ring: ringInk,
                  trailing: skin.palette.chartNeutral,
                  pin: pinInk,
                  stroke: skin.depth.borderWidth,
                ),
              )
            : AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _RadarPainter(
                    phases: <double>[_c.value, (_c.value + 0.5) % 1.0],
                    ring: ringInk,
                    trailing: skin.palette.chartNeutral,
                    pin: pinInk,
                    stroke: skin.depth.borderWidth,
                  ),
                ),
              ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.phases,
    required this.ring,
    required this.trailing,
    required this.pin,
    required this.stroke,
  });

  /// Empty when nothing moves — the resting frame is the pin alone.
  final List<double> phases;
  final Color ring;
  final Color trailing;
  final Color pin;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final span = size.shortestSide - 40;

    for (var i = 0; i < phases.length; i++) {
      final t = phases[i];
      // The LEADING ring is the lit one. Opacity is banned as a state
      // channel, so the trailing ring is a different declared colour rather
      // than the same one faded.
      canvas.drawCircle(
        centre,
        20 + span * t / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? stroke : 1.5
          ..color = i == 0 ? ring : trailing,
      );
    }

    // The pin: a 2px-stroke teardrop — a circle on a stem — at 40dp.
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = pin;
    canvas.drawCircle(centre.translate(0, -6), 9, p);
    canvas.drawLine(centre.translate(0, 3), centre.translate(0, 14), p);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.phases.length != phases.length ||
      old.ring != ring ||
      old.pin != pin ||
      (phases.isNotEmpty && old.phases.first != phases.first);
}
