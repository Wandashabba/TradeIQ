import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/agent_motion.dart' show reduceMotion;
import '../../../core/widgets/dimmed_aisle_backdrop.dart';

/// The splash: the aisle footage dimmed to texture, the wordmark fading up,
/// and self-managed navigation at `max(5s, session-restore)` — never before
/// 5 seconds (the brand hold), never before restore resolves (advancing blind
/// would route a logged-in manager to sign-in). Tap anywhere skips the hold
/// but still waits for restore. The router's redirect exempts '/' so nothing
/// cuts the hold short.
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

    // Under reduced motion the video stays on its first frame — still a
    // photograph of a real aisle, just not a moving one. There is no longer a
    // pause control: the WCAG 2.2.2 (Level A) concern it served applied to the
    // old indefinite loop, and this screen now auto-advances within ~5 seconds
    // — under the SC's 5-second threshold — with the whole tap surface acting
    // as the skip.
    if (!reduceMotion(context)) {
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
    final still = reduceMotion(context);
    // The auth screens ship dark-only this pass (restyling them is out of 5a
    // scope), so pin them dark inline now that PinnedDark is gone.
    return Theme(
      data: AppTheme.dark(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _skipped = true;
          _maybeAdvance();
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DimmedAisleBackdrop(controller: _videoController),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: still ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: still ? 0 : 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 12),
                      child: child,
                    ),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'TRADE'),
                        TextSpan(
                          text: 'IQ',
                          style: TextStyle(color: AppColors.blueLight),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
