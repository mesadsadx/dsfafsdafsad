import 'dart:ui';
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: const Color(0x66000000),
          child: child,
        ),
      ),
    );
  }
}
