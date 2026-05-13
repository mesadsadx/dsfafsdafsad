import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NativeLiquidGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color fallbackColor;

  const NativeLiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(36)),
    this.fallbackColor = const Color(0xB8161B22),
  });

  // iOS tint is slightly lighter/more transparent for a true frosted look
  Color get _iosTint => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? const Color(0x22FFFFFF)
      : fallbackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          color: _iosTint,
          child: child,
        ),
      ),
    );
  }
}
