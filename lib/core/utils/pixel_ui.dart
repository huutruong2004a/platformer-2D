import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PixelUI {
  // Font Style chuẩn
  static TextStyle font({double size = 24, Color color = Colors.white}) {
    return GoogleFonts.vt323(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.bold,
    );
  }

  // Card Panel (Khung nền)
  static Widget card({
    required Widget child,
    Color color = Colors.white,
    Color borderColor = Colors.black,
    double padding = 20,
  }) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(8, 8),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  // Button (Nút bấm)
  static Widget button({
    required String text,
    required VoidCallback onPressed,
    Color color = const Color(0xFF88C070), // Màu xanh Gameboy
    Color textColor = Colors.black,
    double width = 200,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: const [
             BoxShadow(
              color: Colors.black, // Bóng cứng
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: font(size: 28, color: textColor),
          ),
        ),
      ),
    );
  }
  
  // Icon Button nhỏ
  static Widget iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.white,
    Color iconColor = Colors.black,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
             BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  // Input Field (Ô nhập liệu)
  static Widget textField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
           BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        style: font(size: 24, color: Colors.black),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: font(size: 24, color: Colors.grey),
          isDense: true,
        ),
      ),
    );
  }

  // Player Slot (Ô hiển thị người chơi)
  static Widget playerSlot({
    required int index,
    required bool isJoined,
    required String name,
    required bool isMe,
  }) {
    // Màu theo index: Xanh lá, Xanh dương, Hồng, Vàng
    final colors = [
      const Color(0xFF88C070), // Green
      const Color(0xFF88a0C0), // Blue
      const Color(0xFFe080a0), // Pink
      const Color(0xFFe0c070), // Yellow
    ];
    
    final color = colors[index % colors.length];

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 120,
        decoration: BoxDecoration(
          color: isJoined ? color : Colors.black.withOpacity(0.5),
          border: Border.all(
            color: isMe ? Colors.white : Colors.black, 
            width: isMe ? 4 : 2
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar Placeholder (Sau này thay bằng Sprite thật)
            Container(
              width: 40, 
              height: 40, 
              decoration: BoxDecoration(
                color: isJoined ? Colors.white.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
                border: isJoined ? Border.all(color: Colors.black, width: 2) : null,
              ),
              child: isJoined 
                ? const Icon(Icons.person, color: Colors.black)
                : const Icon(Icons.add, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Text(
              isJoined ? "P${index + 1}" : "EMPTY",
              style: font(size: 20, color: isJoined ? Colors.black : Colors.white54),
            ),
            if (isMe)
              Text("(YOU)", style: font(size: 16, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}