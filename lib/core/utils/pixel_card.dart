import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class PixelCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final Color? backgroundColor;

  const PixelCard({
    super.key,
    required this.child,
    this.width,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(4), // Viền ngoài cùng (Border 1)
      decoration: BoxDecoration(
        color: AppTheme.accent, // Màu viền
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.background, // Màu nền
          border: Border.all(color: AppTheme.surface, width: 4), // Viền trong (Border 2)
        ),
        child: child,
      ),
    );
  }
}
