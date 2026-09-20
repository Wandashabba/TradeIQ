import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/motion_budget.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/entry_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/dimmed_aisle_backdrop.dart';
import 'entry_brand.dart';

/// THE SPLASH — the aisle, the wordmark, and five seconds.
///
/// It advances at `max(5s, session-restore)`: never before 5 seconds (the
/// brand hold), never before restore resolves (advancing blind would route a
/// logged-in manager to sign-in). Tap anywhere skips the hold but still waits
/// for restore. The router's redirect exempts '/' so nothing cuts the hold
/// short.
///
/// ## Amber: none, in any skin
///
/// Nothing here is armed and nothing here is a control, so the route declares
/// no claims at all and the census counts zero objects in Night, Day and Veld.
/// A splash is the one screen in the product with nothing to commit.
///
/// ## The one screen with no skin cycle, and why that is not an exception
///
/// [TorchShell] puts the cycle on every screen because the control that gets
/// somebody out of a skin they cannot read belongs everywhere they can reach.
/// This screen has no chrome at all: no header, no bottom region, no scroll,
/// and **no words to read** beyond a wordmark. It holds for five seconds, the
/// whole surface is the skip, and the screen it hands to carries the cycle. A
/// 56dp control on a five-second brand moment would be a control nobody has
/// time to find and a tap target competing with the skip.
///
/// ## The footage is Night's ground, and Night's only
///
/// Day is paper and Veld removes every image in the system (unify §4); a
/// near-black video under a white ground is not a lighter version of the same
/// idea, it is a different screen. So Day and Veld get the skin's own ground
/// and the same mark on it.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  late final VideoPlayerController _videoController;
  Timer? _hold;
  bool _holdDone = false;
  bool _skipped = false;
  bool _navigated = false;

  /// Autoplay is decided once, the first time we have a [MediaQuery] to ask.
  bool _decidedAutoplay = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'assets/videos/Steadycam_gliding_down_aisle_202607102247.mp4',
    );
    _initializeVideo();
    _hold = Timer(const Duration(seconds: 5), () {
      _holdDone = true;
      _maybeAdvance();
    });
    // Session restore resolving is the other half of max(5s, restore).
    ref.listenManual(sessionControllerProvider, (_, _) => _maybeAdvance());
  }

  Future<void> _initializeVideo() async {
    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.setVolume(0);
      await _videoController.setPlaybackSpeed(0.45);
      // Deliberately NOT played here. Whether it should autoplay depends on the
      // user's reduced-motion setting, and initState has no MediaQuery to ask —
      // see didChangeDependencies.
      if (mounted) {
        setState(() {});
      }
    } on UnimplementedError {
      // Widget tests have no platform video player; leave the background blank.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decidedAutoplay || !_videoController.value.isInitialized) return;
    _decidedAutoplay = true;

    // Under the motion budget the video stays on its first frame — still a
    // photograph of a real aisle, just not a moving one. There is no longer a
    // pause control: the WCAG 2.2.2 (Level A) concern it served applied to the
    // old indefinite loop, and this screen now auto-advances within ~5 seconds
    // — under the SC's 5-second threshold — with the whole tap surface acting
    // as the skip.
    //
    // `MotionBudget.still` and not `reduceMotion` alone: Veld has no motion at
    // all, and Veld does not render the footage either.
    if (!MotionBudget.of(context).still) {
      _videoController.play();
    }
  }

  /// Navigates when BOTH gates are open: (5s elapsed OR user tapped) AND the
  /// session restore has resolved. Never before restore — advancing blind
  /// would route a logged-in manager to sign-in (spec: the race, defined).
  void _maybeAdvance() {
    if (_navigated || !mounted) return;
    if (!_holdDone && !_skipped) return;
    final session = ref.read(sessionControllerProvider);
    if (session.isLoading) return;
    _navigated = true;
    final role = session.value?.role;
    context.go(switch (role) {
      null => '/login',
      'field_agent' => '/today',
      _ => '/dashboard',
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntryTorchlightRoute(
      child: Builder(
        builder: (context) {
          final skin = context.skin;
          final still = MotionBudget.of(context).still;
          final wordmark = TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: still ? 1 : 0, end: 1),
            duration: Duration(milliseconds: still ? 0 : 900),
            curve: TiqMotion.enterCurve,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 12),
                child: child,
              ),
            ),
            child: const EntryBrand(monogram: 52),
          );

          return TorchScope(
            skin: skin,
            phase: 'holding',
            navRenders: false,
            tabbedRoute: false,
            claims: const <TorchClaim>[],
            child: DefaultTextStyle(
              style: skin.text.body.style(color: skin.palette.ink1),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _skipped = true;
                  _maybeAdvance();
                },
                child: ColoredBox(
                  color: skin.palette.ground,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // Night only. The dim is a flat colour over the frame,
                      // not a blur or a saveLayer — nothing new on the paint
                      // budget.
                      if (skin.mode == SkinMode.night)
                        DimmedAisleBackdrop(controller: _videoController),
                      Center(child: wordmark),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
