import 'package:flutter/material.dart';

/// The full-width primary action on the two public screens.
///
/// Replaces `PrimaryGradientButton`, a pre-redesign fossil: a 999px pill with
/// an Apple system-blue gradient and a coloured glow, on an app whose design
/// system squared everything off to 3px and moved to the brand palette.
/// `design/index.html` lists gradient pill buttons as removed, so the public
/// screens were the last place still contradicting it.
///
/// Styling comes from `filledButtonTheme` rather than being restated here —
/// that is the whole point of the change, and a second hard-coded button would
/// only start the same drift again.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      // Taller than the console's dense rows: these two screens are used
      // one-handed, outdoors, often in a hurry.
      height: 48,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (trailing != null) ...[const SizedBox(width: 9), trailing!],
                ],
              ),
      ),
    );
  }
}
