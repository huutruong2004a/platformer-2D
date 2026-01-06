import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Bảng màu Retro (Dựa trên Kenney 1-bit)
  static const Color background = Color(0xFF2C2C2C); // Xám đậm
  static const Color surface = Color(0xFF4A4A4A);    // Xám vừa
  static const Color accent = Color(0xFFE0E0E0);     // Trắng đục
  static const Color primary = Color(0xFF88C070);    // Xanh Gameboy (Optional)
  static const Color text = Colors.white;

  // Text Style Pixel
  static TextStyle get pixelFont {
    return GoogleFonts.vt323(
      color: text,
      fontSize: 24,
    );
  }
  
  // Style cho nút bấm Overlay
  static ButtonStyle get pixelButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: surface,
      foregroundColor: text,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Vuông vức
        side: BorderSide(color: accent, width: 2), // Viền trắng
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      textStyle: pixelFont.copyWith(fontSize: 28),
    );
  }
}
