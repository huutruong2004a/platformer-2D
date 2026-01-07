import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart' hide Text;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ==========================================
// 1. BACKGROUND: FIX LỆCH MAP & NHÂN VẬT
// ==========================================
class MenuBackgroundGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFFb0e0f8); 

  @override
  Future<void> onLoad() async {
    // --- LOAD MAP ---
    final map = await TiledComponent.load('lobby.tmx', Vector2.all(18));
    add(map);

    // Kích thước thật của map (25x20 tiles * 18px)
    final mapWidth = 25 * 18.0;
    final mapHeight = 20 * 18.0;

    // --- LOGIC SCALE & POSITION MỚI (FIX LỖI) ---
    // Tính tỉ lệ scale để map nằm trọn trong màn hình (Contain/Fit)
    final scaleX = size.x / mapWidth;
    final scaleY = size.y / mapHeight;
    // Dùng max để fill màn hình (như cover), nhưng nếu bị cắt quá nhiều thì dùng min.
    // Ở đây ta dùng max để fill, nhưng sẽ anchor map ở giữa (center).
    final scale = max(scaleX, scaleY); 
    
    map.scale = Vector2.all(scale);
    
    // Tính offset để đưa tâm map về tâm màn hình
    // Công thức: (Màn hình - (Map * Scale)) / 2
    final offsetX = (size.x - (mapWidth * scale)) / 2;
    final offsetY = (size.y - (mapHeight * scale)) / 2;
    
    map.position = Vector2(offsetX, offsetY);

    // --- MÂY TRÔI ---
    final spriteSheet = await images.load('tilemap_packed.png');
    final cloudSprite = Sprite(spriteSheet, srcPosition: Vector2(162, 162), srcSize: Vector2(18, 18));
    
    add(MovingCloud(sprite: cloudSprite, y: size.y * 0.1, speed: 15, scale: 3.0, opacity: 0.6));
    add(MovingCloud(sprite: cloudSprite, y: size.y * 0.3, speed: 8, scale: 2.0, opacity: 0.4));
    add(MovingCloud(sprite: cloudSprite, y: size.y * 0.5, speed: 20, scale: 2.5, opacity: 0.2));


    // --- NHÂN VẬT ---
    final charSheet = await images.load('tilemap-characters_packed.png');
    
    // Tính toán lại vị trí đứng dựa trên Map đã căn giữa
    // Trong lobby.tmx, mặt đất ở khoảng tile thứ 16-17 từ trên xuống (Row 16)
    // 16 * 18 = 288px (tọa độ Y trong map gốc)
    const groundRowInTiled = 16.0; 
    final groundYInScreen = offsetY + (groundRowInTiled * 18.0 * scale);
    
    // Vùng an toàn để đi lại (Khoảng giữa map)
    final mapLeft = offsetX;
    final mapRight = offsetX + (mapWidth * scale);
    
    // Padding để ko đi ra khỏi mép
    final safeMinX = mapLeft + (50 * scale);
    final safeMaxX = mapRight - (50 * scale);

    for (int i = 0; i < 4; i++) {
      // Rải đều vị trí xuất phát
      final startX = safeMinX + (i * ((safeMaxX - safeMinX) / 4));
      
      add(RandomWalkPlayer(
        sprite: Sprite(charSheet, srcPosition: Vector2(i * 24.0, 0), srcSize: Vector2(24, 24)),
        position: Vector2(startX, groundYInScreen),
        size: Vector2(24, 24) * scale, // Scale nhân vật theo map
        minX: safeMinX,
        maxX: safeMaxX,
      ));
    }
  }
}

// --- COMPONENT: MÂY BAY ---
class MovingCloud extends SpriteComponent with HasGameRef {
  final double speed;
  MovingCloud({required Sprite sprite, required double y, required this.speed, double scale = 1.0, double opacity = 1.0}) 
      : super(sprite: sprite, position: Vector2(-150, y), scale: Vector2.all(scale)) {
    paint.color = Colors.white.withOpacity(opacity);
  }
  @override
  void update(double dt) {
    x += speed * dt;
    if (x > gameRef.size.x) x = -width;
  }
}

// --- COMPONENT: NHÂN VẬT ĐI LẠI (AI ĐƠN GIẢN) ---
class RandomWalkPlayer extends SpriteComponent {
  final double minX;
  final double maxX;
  double moveSpeed = 40;
  double waitTime = 0;
  int direction = 1; // 1: Right, -1: Left
  final Random _rnd = Random();

  RandomWalkPlayer({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.minX,
    required this.maxX,
  }) : super(sprite: sprite, position: position, size: size, anchor: Anchor.bottomCenter) {
    direction = _rnd.nextBool() ? 1 : -1;
    moveSpeed = 30 + _rnd.nextDouble() * 40; 
  }

  @override
  void update(double dt) {
    if (waitTime > 0) {
      waitTime -= dt;
      return;
    }

    x += moveSpeed * direction * dt;

    if (direction == 1 && isFlippedHorizontally) {
      flipHorizontally();
    } else if (direction == -1 && !isFlippedHorizontally) {
      flipHorizontally();
    }

    bool hitWall = false;
    if (x < minX) {
      x = minX;
      hitWall = true;
    } else if (x > maxX) {
      x = maxX;
      hitWall = true;
    }

    if (hitWall || _rnd.nextDouble() < 0.01) {
      _changeAction();
    }
  }

  void _changeAction() {
    waitTime = 0.5 + _rnd.nextDouble() * 1.5;
    if (_rnd.nextBool()) direction *= -1;
    moveSpeed = 30 + _rnd.nextDouble() * 40;
  }
}

// ==========================================
// 2. UI (GIỮ NGUYÊN)
// ==========================================
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Responsive sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final titleSize = isSmallScreen ? 40.0 : 60.0;
    final subtitleSize = isSmallScreen ? 24.0 : 35.0;
    final buttonWidth = isSmallScreen ? screenWidth * 0.75 : 280.0;
    final spacing = isSmallScreen ? 12.0 : 16.0;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background game
          IgnorePointer(
            child: GameWidget(game: MenuBackgroundGame()),
          ),
          Container(color: Colors.black.withOpacity(0.3)), // Overlay
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: isSmallScreen ? 20 : 30),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 24 : 40, 
                        vertical: isSmallScreen ? 12 : 20
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5f5f5f),
                        border: Border.all(color: const Color(0xFFe0e0e0), width: isSmallScreen ? 3 : 4),
                        boxShadow: [BoxShadow(color: Colors.black54, offset: Offset(isSmallScreen ? 4 : 6, isSmallScreen ? 4 : 6), blurRadius: 0)],
                      ),
                      child: Column(
                        children: [
                          _pixelText('PICO', titleSize, const Color(0xFFb8f889)),
                          const SizedBox(height: 5),
                          _pixelText('ADVENTURE', subtitleSize, Colors.white),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 30 : 50),
                    PixelButton(label: "START GAME", icon: Icons.play_arrow, color: const Color(0xFFb8f889), width: buttonWidth, onPressed: () => context.go('/levels')),
                    SizedBox(height: spacing),
                    PixelButton(label: "MULTIPLAYER", icon: Icons.groups, color: const Color(0xFFf8b789), width: buttonWidth, onPressed: () => context.go('/lobby')),
                    SizedBox(height: spacing),
                    PixelButton(label: "SETTINGS", icon: Icons.settings, color: const Color(0xFFe0e0e0), width: buttonWidth, onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pixelText(String text, double size, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: GoogleFonts.vt323().fontFamily,
        fontSize: size * 1.2,
        fontWeight: FontWeight.normal,
        color: color,
        letterSpacing: 2,
        height: 0.9,
        shadows: [Shadow(offset: const Offset(3, 3), color: Colors.black.withOpacity(0.5), blurRadius: 0)],
      ),
    );
  }
}

class PixelButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback onPressed;

  const PixelButton({super.key, required this.label, required this.icon, required this.color, this.width = 280, required this.onPressed});

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSmall = widget.width < 250;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onPressed(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: widget.width,
        height: isSmall ? 48 : 60,
        margin: EdgeInsets.only(top: _isPressed ? 4 : 0),
        decoration: BoxDecoration(
          color: widget.color,
          border: Border.all(color: Colors.black, width: isSmall ? 2 : 3),
          boxShadow: _isPressed ? [] : [BoxShadow(color: Colors.black, offset: Offset(isSmall ? 3 : 4, isSmall ? 3 : 4), blurRadius: 0)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.black, size: isSmall ? 22 : 28),
            SizedBox(width: isSmall ? 6 : 10),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: GoogleFonts.vt323().fontFamily,
                color: Colors.black,
                fontSize: isSmall ? 20 : 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
