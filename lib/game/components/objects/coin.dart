import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'dart:ui';
import '../../pico_game.dart';
import '../player/player.dart';

class Coin extends BodyComponent<Forge2DGame> with ContactCallbacks, HasGameRef<Forge2DGame> {
  final Vector2 position;
  final Vector2 size;
  late final String coinId; // Unique ID based on position

  Coin({required this.position, required this.size});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    renderBody = false;
    
    // Generate unique ID from position
    coinId = '${position.x.toInt()}_${position.y.toInt()}';
    
    // Register with game for remote sync
    (gameRef as dynamic).registerCoin(coinId, this);
    
    final sprite = await gameRef.loadSprite(
      'tilemap_packed.png',
      srcPosition: Vector2(198, 126),
      srcSize: Vector2(18, 18),
    );

    add(SpriteComponent(
      sprite: sprite,
      size: size,
      anchor: Anchor.center,
    ));
  }

  @override
  Body createBody() {
    final shape = CircleShape();
    shape.radius = size.x / 2;

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
  void render(Canvas canvas) {
    // Không vẽ debug shape
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Player && other.isControllable) {
      // Chỉ xử lý khi player của MÌNH nhặt xu
      removeFromParent();
      (gameRef as dynamic).addCoin(coinId: coinId, broadcast: true);
    }
  }
}

