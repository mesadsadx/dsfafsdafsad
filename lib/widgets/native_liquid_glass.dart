import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            const Positioned.fill(
              child: UiKitView(
                viewType: 'liquid_glass_view',
                layoutDirection: TextDirection.ltr,
                creationParamsCodec: StandardMessageCodec(),
              ),
            ),
            child,
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: const Color(0x28FFFFFF),
          child: child,
        ),
      ),
    );
  }
}
