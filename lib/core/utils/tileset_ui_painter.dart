import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'ui_asset_loader.dart';

class TilesetBox extends StatelessWidget {
  final Widget child;
  final int tileX; // Tọa độ X của tile trong ảnh (theo đơn vị tile 18px)
  final int tileY; // Tọa độ Y
  final bool tiling; // True = Lặp lại (Background), False = Kéo dãn (hoặc 9-slice đơn giản)
  final EdgeInsets padding;
  final double scale; // Phóng to pixel

  const TilesetBox({
    super.key,
    required this.child,
    required this.tileX,
    required this.tileY,
    this.tiling = false,
    this.padding = const EdgeInsets.all(16),
    this.scale = 3.0, // Mặc định phóng to gấp 3 lần cho rõ pixel
  });

  // Factory cho nền gạch xám (Background)
  // Kenney: Row 6, Col 4 (Brick Wall) ~ x=4, y=6
  factory TilesetBox.brickBackground({required Widget child}) {
    return TilesetBox(
      tileX: 4, 
      tileY: 6,
      tiling: true,
      padding: EdgeInsets.zero,
      scale: 4.0,
      child: child,
    );
  }

  // Factory cho Panel (Khung gỗ/đá)
  // Kenney: Row 0, Col 4 (Block) ~ x=4, y=0
  factory TilesetBox.panel({required Widget child, double? width}) {
    return TilesetBox(
      tileX: 1, // Stone Block (Row 0, Col 1)
      tileY: 0,
      scale: 3.0, // Viền dày 18 * 3 = 54px
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        child: child
      ),
    );
  }
  
  // Factory cho Button
  factory TilesetBox.button({required Widget child, required VoidCallback onPressed}) {
    return TilesetBox(
      tileX: 6, // Một khối màu khác (Row 0, Col 6)
      tileY: 0, 
      scale: 3.0,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (UiAssetLoader.image == null) return Container(color: Colors.grey, child: child);

    return CustomPaint(
      painter: _TilesetPainter(
        image: UiAssetLoader.image!,
        tileX: tileX,
        tileY: tileY,
        tiling: tiling,
        scale: scale,
      ),
      child: Container(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _TilesetPainter extends CustomPainter {
  final ui.Image image;
  final int tileX;
  final int tileY;
  final bool tiling;
  final double scale;

  _TilesetPainter({
    required this.image,
    required this.tileX,
    required this.tileY,
    required this.tiling,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const double tileSize = 18.0; // Kích thước gốc trong ảnh
    
    // Vùng chọn trên ảnh gốc (Source Rect)
    final srcRect = Rect.fromLTWH(
      tileX * tileSize + (tileX * 0), // + spacing nếu có
      tileY * tileSize + (tileY * 0), 
      tileSize, 
      tileSize
    );

    if (tiling) {
      // Vẽ lặp lại (Pattern)
      final double renderSize = tileSize * scale;
      for (double x = 0; x < size.width; x += renderSize) {
        for (double y = 0; y < size.height; y += renderSize) {
          final dstRect = Rect.fromLTWH(x, y, renderSize, renderSize);
          canvas.drawImageRect(image, srcRect, dstRect, paint);
        }
      }
    } else {
      // Vẽ kéo dãn 9-slice (Đơn giản hóa: Vẽ 1 hình lớn cho nhanh, hoặc viền)
      // Ở đây tôi sẽ vẽ kiểu "Block" - tức là vẽ tile đó phóng to lấp đầy khung
      // Để làm 9-slice chuẩn cần nhiều tile khác nhau (góc, cạnh).
      // Tạm thời vẽ fill toàn bộ bằng texture đó (Stretch)
      // Nhưng Pixel Art mà stretch thì vỡ. Nên ta vẽ kiểu Center Tile Repeated.
      
      // Vẽ viền (Border) bằng cách lặp lại tile xung quanh?
      // Đơn giản nhất: Fill toàn bộ background bằng tile đó (Repeat) nhưng có viền
      final double renderSize = tileSize * scale;
      // Vẽ 1 lớp nền tối
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
      
      // Vẽ texture đè lên
       for (double x = 0; x < size.width; x += renderSize) {
        for (double y = 0; y < size.height; y += renderSize) {
          // Chỉ vẽ nếu nằm trong vùng (Clip)
           final dstRect = Rect.fromLTWH(x, y, renderSize, renderSize);
           canvas.drawImageRect(image, srcRect, dstRect, paint);
        }
      }
      
      // Vẽ viền đen bao quanh để tạo khối
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawRect(Rect.fromLTWH(0,0,size.width, size.height), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
