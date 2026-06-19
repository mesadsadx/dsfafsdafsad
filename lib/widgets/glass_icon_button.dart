import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Circular frosted-glass icon button. On iOS uses real blur; elsewhere uses
/// a semi-transparent surface tint so it looks consistent.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final useBlur = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    Widget content = Icon(icon, color: AppColors.textPrimary, size: 18);

    if (useBlur) {
      content = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Center(child: content),
          ),
        ),
      );
    } else {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceVariant,
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Center(child: content),
      );
    }

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
