import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/game_config.dart';
import '../../mixins/pico_controls.dart';

// Snapshot Data Structure
class MoveSnapshot {
  final Vector2 position;
  final Vector2 velocity;
  final DateTime timestamp;

  MoveSnapshot(this.position, this.velocity, this.timestamp);
}

class Player extends BodyComponent<Forge2DGame> with KeyboardHandler, HasGameRef<Forge2DGame> {
  final Vector2 initialPosition;
  final bool isControllable; // Cờ kiểm soát input
  final int skinIndex; // 0: Green, 1: Blue, 2: Pink, 3: Yellow
  late SpriteComponent spriteComponent;

  int horizontalDirection = 0;
  bool hasJumped = false;
  int jumpCount = 0; // 0: Ground, 1: First Jump, 2: Double Jump
  bool _needsRespawn = false;
  bool _wasMobileJumpPressed = false; // Theo dõi trạng thái nút nhảy mobile frame trước

  // --- MULTIPLAYER INTERPOLATION ---
  final List<MoveSnapshot> _positionBuffer = [];
  // Render delay: 100ms (Buffers packets to ensure smoothness)
  static const int _renderDelayMs = 100;

  Player({
    required this.initialPosition, 
    this.isControllable = true, 
    this.skinIndex = 0,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Ẩn hitbox trắng của Forge2D
    renderBody = false;

    // Calculate srcPosition based on skinIndex
    final double spriteX = (skinIndex % 4) * 24.0; 

    // Load character sprite từ sheet
    final sprite = await gameRef.loadSprite(
      'tilemap-characters_packed.png',
      srcPosition: Vector2(spriteX, 0),
      srcSize: Vector2(24, 24),
    );

    spriteComponent = SpriteComponent(
      sprite: sprite,
      size: Vector2.all(24),
      anchor: Anchor.bottomCenter, // Dùng chân làm mốc
      position: Vector2(0, 11), // Đặt chân sprite vào đáy hitbox (hitbox cao 22, tâm 0, đáy 11)
    );
    
    add(spriteComponent);
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      position: initialPosition,
      type: BodyType.dynamic,
      fixedRotation: true,
      allowSleep: false, 
      userData: this,
      gravityScale: Vector2(1.0, 8.0),
      linearDamping: 0.0,
    );

    final body = world.createBody(bodyDef);

    // FIX LỖI KẸT MAP: Dùng 2 Fixture
    // 1. Fixture Thân (Hình hộp, ma sát 0 để không dính tường)
    final bodyShape = PolygonShape();
    bodyShape.setAsBox(7.0, 8.0, Vector2(0, -2), 0.0); // Thân ngắn lại chút
    body.createFixture(FixtureDef(
      bodyShape,
      friction: 0.0, // Không ma sát với tường
      restitution: 0.0,
      density: 5.0,
    ));

    // 2. Fixture Chân (Hình tròn, ma sát cao để đứng vững)
    final footShape = CircleShape();
    footShape.radius = 7.0;
    footShape.position.setValues(0, 4.0); // Đặt ở dưới đáy
    body.createFixture(FixtureDef(
      footShape,
      friction: GameConfig.playerFriction, // Giữ nguyên ma sát 10.0 bạn muốn
      restitution: 0.0,
      density: 5.0,
    ));

    return body;
  }
  
  @override
  void update(double dt) {
    if (_needsRespawn) {
      _performRespawn();
      _needsRespawn = false;
    }

    super.update(dt);
    final velocity = body.linearVelocity;
    
    // Logic chạm đất
    bool isGrounded = velocity.y.abs() < 0.1;
    if (isGrounded && velocity.y >= 0) {
      jumpCount = 0;
    }

    // 1. INPUT LOGIC (Local Player)
    double inputX = 0;

    if (isControllable) {
      if (horizontalDirection != 0) {
        inputX = horizontalDirection.toDouble();
      }
      if ((gameRef as PicoControls).isLeftPressed) inputX = -1;
      if ((gameRef as PicoControls).isRightPressed) inputX = 1;
      
      // Movement
      double currentSpeed = GameConfig.moveSpeed;
      if (!isGrounded) {
        currentSpeed *= GameConfig.longJumpMultiplier;
      }
      velocity.x = inputX * currentSpeed;

      // Flip Sprite
      if (inputX != 0) {
        spriteComponent.scale.x = inputX.sign;
      }

      // Jump Logic
      bool mobileJumpJustPressed = (gameRef as PicoControls).isJumpPressed && !_wasMobileJumpPressed;
      _wasMobileJumpPressed = (gameRef as PicoControls).isJumpPressed;

      if (hasJumped || mobileJumpJustPressed) {
         if (jumpCount == 0 && isGrounded) {
            // Jump 1
            jumpCount = 1;
            body.linearVelocity = Vector2(velocity.x, GameConfig.jumpForce);
         } else if (jumpCount == 1) {
            // Double Jump
            jumpCount = 2;
            body.linearVelocity = Vector2(velocity.x, GameConfig.doubleJumpForce);
         }
         hasJumped = false;
      } else {
        body.linearVelocity = velocity;
      }
    }

    // Terminal Velocity
    if (body.linearVelocity.y > GameConfig.terminalVelocity) {
      body.linearVelocity = Vector2(body.linearVelocity.x, GameConfig.terminalVelocity);
    }

    // Pit Check
    if (body.position.y > 500) { 
      respawn();
    }
    
    // 2. INTERPOLATION LOGIC (Remote Player) - SNAPSHOT BUFFERING
    if (!isControllable) {
      // Disable physics forces
      body.gravityScale = Vector2.zero();
      body.linearVelocity = Vector2.zero();

      // If buffer is empty, do nothing
      if (_positionBuffer.isEmpty) return;

      // Target Render Time = NOW - 100ms
      final renderTime = DateTime.now().subtract(const Duration(milliseconds: _renderDelayMs));

      // Cleanup: Remove old snapshots (older than renderTime - 1s safety margin)
      // Keep at least one older than renderTime to be the "Start" point.
      while (_positionBuffer.length > 2 && _positionBuffer[1].timestamp.isBefore(renderTime)) {
        _positionBuffer.removeAt(0);
      }

      // Interpolate between the first two snapshots in buffer
      if (_positionBuffer.length >= 2) {
        final startSnap = _positionBuffer[0];
        final endSnap = _positionBuffer[1];

        // Calculate interpolation factor (alpha)
        final totalDuration = endSnap.timestamp.difference(startSnap.timestamp).inMilliseconds;
        final timePassed = renderTime.difference(startSnap.timestamp).inMilliseconds;
        
        double alpha = 0.0;
        if (totalDuration > 0) {
          alpha = (timePassed / totalDuration).clamp(0.0, 1.0);
        }

        // Linear Interpolation
        final newPos = startSnap.position + (endSnap.position - startSnap.position) * alpha;
        
        // Anti-Sliding: Nếu đích đến là đứng yên, hãy dừng dứt khoát hơn
        if (endSnap.velocity.length2 == 0) {
           body.linearVelocity = Vector2.zero();
           // Snap vị trí nếu đã rất gần đích (tránh trượt nhẹ)
           if (newPos.distanceTo(endSnap.position) < 1.0) {
              body.setTransform(endSnap.position, 0);
           } else {
              body.setTransform(newPos, 0);
           }
        } else {
           body.setTransform(newPos, 0);
        }
        
        // Anti-Teleport Check (if distance > 50px, snap immediately)
        if (newPos.distanceTo(body.position) > 50.0) {
           body.setTransform(newPos, 0);
        } else {
           body.setTransform(newPos, 0);
        }

        // Flip Sprite based on velocity
        if (endSnap.velocity.x != 0) {
           spriteComponent.scale.x = endSnap.velocity.x.sign;
        }
      } else if (_positionBuffer.isNotEmpty) {
        // Fallback: Only 1 snapshot (e.g., initial spawn or lag spike)
        final snap = _positionBuffer.first;
        if (snap.position.distanceTo(body.position) > 2.0) {
           // Lerp gently to the latest known position
           final newPos = body.position + (snap.position - body.position) * (dt * 10);
           body.setTransform(newPos, 0);
        }
      }
    } else if (isControllable) {
       // Ensure gravity is restored if it was ever disabled
       body.gravityScale = Vector2(1.0, 8.0);
    }
  }

  // --- MULTIPLAYER UPDATE RECEIVER ---
  void updateStateFromServer(double x, double y, double vx, double vy) {
    var timestamp = DateTime.now();
    
    // ANTI-BUNCHING (Xử lý dồn toa gói tin)
    // Nếu gói tin đến quá sát nhau (do mạng lag hoặc tab throttling), 
    // ta tự động giãn chúng ra 50ms để chuyển động mượt mà trở lại.
    if (_positionBuffer.isNotEmpty) {
      final lastTimestamp = _positionBuffer.last.timestamp;
      final delta = timestamp.difference(lastTimestamp).inMilliseconds;
      
      // Nếu đến nhanh hơn 20ms (chuẩn là 50ms), coi như bị dồn
      if (delta < 20) {
        timestamp = lastTimestamp.add(const Duration(milliseconds: 50));
      }
    }

    // Add new snapshot to buffer
    _positionBuffer.add(MoveSnapshot(
      Vector2(x, y),
      Vector2(vx, vy),
      timestamp,
    ));
    
    // Safety: Limit buffer size
    if (_positionBuffer.length > 20) {
      _positionBuffer.removeAt(0);
    }
  }

  void respawn() {
    _needsRespawn = true;
  }

  void _performRespawn() {
    // Reset Position
    body.setTransform(initialPosition, 0);
    body.linearVelocity = Vector2.zero();
    jumpCount = 0;
    hasJumped = false;
    print('Player Respawned');
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalDirection = 0;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) || keysPressed.contains(LogicalKeyboardKey.keyA)) {
      horizontalDirection = -1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) || keysPressed.contains(LogicalKeyboardKey.keyD)) {
      horizontalDirection = 1;
    }
    
    if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      hasJumped = true;
    }
    return super.onKeyEvent(event, keysPressed);
  }
}