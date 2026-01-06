import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'dart:ui';
import '../../pico_game.dart';
import '../player/player.dart';

class Flag extends BodyComponent<Forge2DGame> with ContactCallbacks, HasGameRef<Forge2DGame> {
  final Vector2 position;
  final Vector2 size;

  Flag({required this.position, required this.size});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    renderBody = false;
    // NOTE: Sprite removed to avoid double-rendering.
  }

  @override
  Body createBody() {
    final shape = PolygonShape();
    shape.setAsBox(size.x / 2, size.y / 2, Vector2.zero(), 0);

    final fixtureDef = FixtureDef(
      shape,
      isSensor: true,
    );

    final bodyDef = BodyDef(
      position: position + Vector2(size.x / 2, size.y / 2),
      type: BodyType.static,
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {}

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Player && other.isControllable) {
      // Gọi liên tục mỗi khi chạm, PicoGame sẽ lo việc lọc trùng
      (gameRef as dynamic).onPlayerAtFlag(broadcast: true);
    }
  }
}

