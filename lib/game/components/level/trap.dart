import 'package:flame_forge2d/flame_forge2d.dart';

class TrapBody extends BodyComponent {
  final double x, y, w, h;

  TrapBody(this.x, this.y, this.w, this.h);

  @override
  Body createBody() {
    final shape = PolygonShape();
    final center = Vector2(x + w / 2, y + h / 2);
    shape.setAsBox(w / 2, h / 2, center, 0);

    final bodyDef = BodyDef(type: BodyType.static);

    final fixtureDef = FixtureDef(
      shape,
      isSensor: true, // true = đi xuyên qua được (để check va chạm trigger)
      userData: 'Trap', // Đánh dấu đây là bẫy
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}