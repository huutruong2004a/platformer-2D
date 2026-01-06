import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'dart:ui';
import '../../pico_game.dart';
import '../player/player.dart';

class Trap extends BodyComponent<Forge2DGame> with ContactCallbacks, HasGameRef<Forge2DGame> {
  final Vector2 position;
  final Vector2 size;

  Trap({required this.position, required this.size});
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    renderBody = false;
    
    // NOTE: Sprite removed to avoid double-rendering.
    // The visual is handled by the Tiled Map 'Tiles' layer.
    // This component acts purely as a Physics Sensor.
    
    /* 
    final sprite = await gameRef.loadSprite(
      'tilemap_packed.png',
      srcPosition: Vector2(144, 54), 
      srcSize: Vector2(18, 18),
    );

    add(SpriteComponent(
      sprite: sprite,
      size: size,
      anchor: Anchor.center,
    )); 
    */
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
      // Chỉ xử lý khi player của MÌNH chạm bẫy
      (gameRef as dynamic).onPlayerDied();
    }
  }
}

