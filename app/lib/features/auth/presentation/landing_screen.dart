import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/agent_motion.dart' show reduceMotion;
import '../../../core/widgets/pinned_dark.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/trade_iq_logo.dart';

/// The public TradeIQ introduction screen.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'assets/videos/Steadycam_gliding_down_aisle_202607102247.mp4',
    );
    _initializeVideo();
  }

  /// Whether the loop is currently running. Drives the control's icon and
  /// label, so the two can never disagree about what tapping will do.
  bool _playing = false;

  /// Autoplay is decided once, the first time we have a [MediaQuery] to ask.
  bool _decidedAutoplay = false;

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

    // A 22s loop with no way to stop it is a WCAG 2.2 Level A failure (SC
    // 2.2.2), and this is the first screen anyone sees. Under reduced motion
    // the video stays on its first frame — still a photograph of a real aisle,
    // just not a moving one — and everyone else gets a control to stop it.
    //
    // This app honours reduceMotion at 23 other sites; landing was the only
    // place with real motion that ignored it.
    if (!reduceMotion(context)) {
      _videoController.play();
      _playing = true;
    }
  }

  Future<void> _togglePlayback() async {
    if (!_videoController.value.isInitialized) return;
    if (_playing) {
      await _videoController.pause();
    } else {
      await _videoController.play();
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PinnedDark(
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.canvas),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoBackground(controller: _videoController),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x0A0F1117),
                      Color(0x3D0F1117),
                      Color(0xC70F1117),
                    ],
                    stops: [0, .52, 1],
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SafeArea(
                    minimum: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) => SizedBox(
                        height: constraints.maxHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const Align(
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TradeIqLogo(size: 120),
                                  SizedBox(height: 20),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: 'Trade'),
                                        TextSpan(
                                          text: 'IQ',
                                          style: TextStyle(
                                            color: AppColors.blueLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      height: 1.08,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Field Execution, In Focus',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFD0D4DE),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  PrimaryActionButton(
                                    label: 'Continue',
                                    trailing: const Icon(
                                      Icons.arrow_forward,
                                      size: 17,
                                    ),
                                    onPressed: () => context.go('/login'),
                                  ),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Last child, so it paints above the scrim and the content — a
              // control that another layer can cover is not a control. Top-left
              // keeps it clear of the centred logo and the bottom action.
              if (_videoController.value.isInitialized)
                Positioned(
                  top: 8,
                  left: 8,
                  child: SafeArea(
                    child: _MotionToggle(
                      playing: _playing,
                      onPressed: _togglePlayback,
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

/// Pause/play for the background loop.
///
/// Carries its own dark disc rather than sitting directly on the footage: the
/// background is moving, so a control tinted against one frame disappears
/// against the next. The disc guarantees the icon's contrast no matter what is
/// behind it, which is the difference between a control and a decoration.
class _MotionToggle extends StatelessWidget {
  const _MotionToggle({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // Describes the effect, not the state — a screen-reader user needs to
      // know what tapping does, not what the video is currently doing.
      label: playing ? 'Pause background video' : 'Play background video',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            // 44px is the smallest comfortable touch target; the icon inside is
            // deliberately smaller than the tappable area.
            width: 44,
            height: 44,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoBackground extends StatelessWidget {
  const _VideoBackground({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final videoSize = controller.value.size;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoSize.width,
          height: videoSize.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
