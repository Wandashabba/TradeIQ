import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The dark brand backdrop shared by the splash and the sign-in screen: the
/// store-aisle footage dimmed to near-black (spec: 88–92% overlay) so it reads
/// as texture, not content.
///
/// The controller is OWNED BY THE CALLER (the splash creates it, sign-in may
/// receive null) because two screens must not fight over one video. When
/// [controller] is null or uninitialised — widget tests have no platform
/// video, and sign-in skips the video entirely — the fallback is a plain
/// near-black gradient, which keeps every layout identical.
class DimmedAisleBackdrop extends StatelessWidget {
  const DimmedAisleBackdrop({super.key, this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final video = controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video != null && video.value.isInitialized)
          AisleFootage(controller: video)
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF101216),
                  Color(0xFF0A0C10),
                  Color(0xFF07080B),
                ],
              ),
            ),
          ),
        // The dim that makes footage read as texture. 90% sits mid-spec.
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xE6060709)), // 90% #060709
        ),
      ],
    );
  }
}

/// The aisle footage alone, cover-fitted. Nothing until [controller] is
/// initialised — widget tests have no platform video.
class AisleFootage extends StatelessWidget {
  const AisleFootage({super.key, this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final video = controller;
    if (video == null || !video.value.isInitialized) {
      return const SizedBox.expand();
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      ),
    );
  }
}
