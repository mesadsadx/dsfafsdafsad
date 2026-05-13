import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final useNative =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return ClipRRect(
      borderRadius: borderRadius,
      child: useNative ? _nativeStack() : _flutterBlur(),
    );
  }

  Widget _nativeStack() {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: UiKitView(
            viewType: 'liquid_glass_view',
            layoutDirection: TextDirection.ltr,
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
        child,
      ],
    );
  }

  Widget _flutterBlur() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        color: fallbackColor,
        child: child,
      ),
    );
  }
}
