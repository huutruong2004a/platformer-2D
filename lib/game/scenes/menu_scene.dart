import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuScene extends FlameGame with TapCallbacks {
  late TiledComponent map;
  final BuildContext context;

  MenuScene(this.context);

  @override
  Future<void> onLoad() async {
    // Load map từ assets/maps/menu_map.tmj
    // Lưu ý: flame_tiled mặc định tìm trong assets/tiles, ta cần chỉ định prefix nếu để ở assets/maps
    // Nhưng để đơn giản và tránh lỗi path, tôi khuyên bạn nên để map trong assets/tiles hoặc config prefix cẩn thận.
    // Ở đây tôi sẽ dùng prefix 'assets/maps/'
        try {
          map = await TiledComponent.load(
            'menu.tmx', 
            Vector2.all(16),
          );
          add(map);
          
          // Parse UI Elements
          final uiLayer = map.tileMap.getLayer<ObjectGroup>('UIElements');
          if (uiLayer != null) {
            for (final obj in uiLayer.objects) {
              if (obj.name == 'StartButton') {
                add(_createInvisibleButton(obj, () => context.go('/levels')));
              } else if (obj.name == 'MultiplayerButton') {
                 add(_createInvisibleButton(obj, () => context.go('/lobby')));
              }
            }
          }
        } catch (e) {
          print('DEBUG: Error loading menu map: $e');
          // Thêm một nền màu xanh để biết là game đang chạy
          add(RectangleComponent(
            size: Vector2(2000, 2000),
            paint: Paint()..color = const Color(0xFF2D2D2D),
          ));
        }  }

  PositionComponent _createInvisibleButton(TiledObject obj, VoidCallback onTap) {
    return ButtonHitbox(
      position: Vector2(obj.x, obj.y),
      size: Vector2(obj.width, obj.height),
      onTap: onTap,
    );
  }
}

class ButtonHitbox extends PositionComponent with TapCallbacks {
  final VoidCallback onTap;

  ButtonHitbox({
    required Vector2 position,
    required Vector2 size,
    required this.onTap,
  }) : super(position: position, size: size);

  @override
  bool get debugMode => true; // Bật debug để thấy khung nút bấm (tắt đi khi release)

  @override
  void onTapUp(TapUpEvent event) {
    onTap();
  }
}
