import 'package:flame_forge2d/flame_forge2d.dart';

class CoinBody extends BodyComponent {
  final double x, y, w, h;

  CoinBody(this.x, this.y, this.w, this.h);

  @override
  Body createBody() {
    final shape = CircleShape();
    // Lấy bán kính theo cạnh nhỏ nhất
    final radius = (w < h ? w : h) / 2;
    shape.radius = radius;
    shape.position.setValues(x + radius, y + radius);

    final bodyDef = BodyDef(type: BodyType.static);

    final fixtureDef = FixtureDef(
      shape,
      isSensor: true,
      userData: 'Coin',
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}