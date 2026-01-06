import 'package:flame_forge2d/flame_forge2d.dart';
import 'dart:ui';

class GroundBody extends BodyComponent {
  final double x, y, w, h;

  GroundBody(this.x, this.y, this.w, this.h) {
    renderBody = false;
  }

  @override
  Body createBody() {
    // 1. Tính toán tâm của vật thể (Box2D dùng tâm)
    final center = Vector2(x + w / 2, y + h / 2);

    final shape = PolygonShape();
    // 2. Tạo hộp với tâm tại (0,0) so với body
    shape.setAsBox(w / 2, h / 2, Vector2.zero(), 0.0);

    final bodyDef = BodyDef(
      position: center, // Đặt body tại đúng tâm vật thể
      type: BodyType.static,
    );
    
    final fixtureDef = FixtureDef(shape, friction: 0.5);

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    // Chắc chắn không vẽ gì cả (fix lỗi hiện ô trắng nếu có)
  }
}