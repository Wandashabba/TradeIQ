import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The blue action button used for primary public flows.
class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
    this.isLoading = false,
    this.isGlass = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final bool isLoading;
  final bool isGlass;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: isGlass
              ? Border.all(color: const Color(0x80FFFFFF), width: 1.1)
              : null,
          boxShadow: isGlass
              ? const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Color(0x59007AFF),
                    blurRadius: 18,
                    spreadRadius: -3,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x66003399),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
          gradient: isGlass
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x99007AFF), Color(0x700052CC)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.blueLight, AppColors.blueDark],
                ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isGlass ? 14 : 0,
              sigmaY: isGlass ? 14 : 0,
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.textPrimary,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.textPrimary,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label),
                        if (trailing != null) ...[
                          const SizedBox(width: 9),
                          trailing!,
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
