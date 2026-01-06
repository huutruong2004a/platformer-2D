import 'dart:ui' as ui;
import 'package:flame/flame.dart';

class UiAssetLoader {
  /// Ảnh tileset đã load, dùng cho UI painting
  static ui.Image? image;

  static Future<void> load() async {
    // Load tất cả assets quan trọng vào cache của Flame
    await Flame.images.loadAll([
      'tilemap_packed.png',
      'tilemap-characters_packed.png',
    ]);
    
    // Lấy ảnh từ cache và lưu vào biến static để TilesetBox dùng
    image = Flame.images.fromCache('tilemap_packed.png');
  }
}
