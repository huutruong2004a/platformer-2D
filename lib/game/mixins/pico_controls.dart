import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

mixin PicoControls on Forge2DGame {
  bool isJumpPressed = false;
  bool isLeftPressed = false; 
  bool isRightPressed = false; 

  void addMobileControls() {
    HudButtonComponent createSpriteButton({
      required Vector2 position, 
      required String label, 
      required VoidCallback onPressed, 
      required VoidCallback onReleased
    }) {
      final spriteNormal = SpriteComponent(
        sprite: Sprite(
          images.fromCache('tilemap_packed.png'),
          srcPosition: Vector2(162, 162),
          srcSize: Vector2(18, 18),
        ),
        size: Vector2(70, 70), // Tăng kích thước nút lên 70 cho dễ bấm
        paint: Paint()..color = Colors.white.withOpacity(0.5), // Giảm độ mờ để đỡ che map
      );

      final spritePressed = SpriteComponent(
        sprite: Sprite(
          images.fromCache('tilemap_packed.png'),
          srcPosition: Vector2(162, 162),
          srcSize: Vector2(18, 18),
        ),
        size: Vector2(70, 70),
        paint: Paint()..color = const Color(0xFF88C070).withOpacity(0.8),
      );

      return HudButtonComponent(
        button: spriteNormal,
        buttonDown: spritePressed,
        position: position,
        onPressed: onPressed,
        onReleased: onReleased,
        children: [
           TextComponent(
              text: label,
              position: Vector2(35, 35), // Căn giữa nút 70x70
              anchor: Anchor.center,
              textRenderer: TextPaint(
                style: const TextStyle(
                  color: Colors.black, 
                  fontSize: 35, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                )
              ),
            ),
        ]
      );
    }

    final viewportSize = camera.viewport.virtualSize;

    // Nút Trái
    final leftButton = createSpriteButton(
      position: Vector2(30, viewportSize.y - 100),
      label: '<',
      onPressed: () => isLeftPressed = true,
      onReleased: () => isLeftPressed = false,
    );
    camera.viewport.add(leftButton);

    // Nút Phải
    final rightButton = createSpriteButton(
      position: Vector2(120, viewportSize.y - 100),
      label: '>',
      onPressed: () => isRightPressed = true,
      onReleased: () => isRightPressed = false,
    );
    camera.viewport.add(rightButton);

    // Nút Nhảy
    final jumpButton = createSpriteButton(
      position: Vector2(viewportSize.x - 100, viewportSize.y - 100),
      label: '^',
      onPressed: () => isJumpPressed = true,
      onReleased: () => isJumpPressed = false,
    );
    camera.viewport.add(jumpButton);
  }
}
