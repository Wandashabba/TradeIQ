import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pinned_dark.dart';
import '../../../core/widgets/primary_gradient_button.dart';
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

  Future<void> _initializeVideo() async {
    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.setVolume(0);
      await _videoController.setPlaybackSpeed(0.45);
      await _videoController.play();
      if (mounted) {
        setState(() {});
      }
    } on UnimplementedError {
      // Widget tests have no platform video player; leave the background blank.
    }
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
                                  PrimaryGradientButton(
                                    label: 'Continue',
                                    isGlass: true,
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
            ],
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
