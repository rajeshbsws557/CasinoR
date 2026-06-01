import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadiusGeometry? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.15,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.boxShadow,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = BorderRadius.circular(16);

    return margin != null
        ? Padding(
            padding: margin!,
            child: _buildBody(defaultRadius),
          )
        : _buildBody(defaultRadius);
  }

  Widget _buildBody(BorderRadius defaultRadius) {
    return ClipRRect(
      borderRadius: borderRadius ?? defaultRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(opacity),
            borderRadius: borderRadius ?? defaultRadius,
            border: border ??
                Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.0,
                ),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
