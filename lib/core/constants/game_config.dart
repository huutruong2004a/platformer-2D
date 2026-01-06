import 'package:flame/components.dart';

class GameConfig {
  // Physics - Cấu hình "Nặng & Dứt khoát"
  static final Vector2 gravity = Vector2(0, 2500.0); 
  static const double jumpForce = -60.0; // Vận tốc nhảy trực tiếp
  static const double doubleJumpForce = -60.0;
  static const double moveSpeed = 50.0; // Chạy chậm lại để dễ kiểm soát
  static const double longJumpMultiplier = 0.55; // Nhảy xa vừa phải
  static const double terminalVelocity = 3000.0;
  
  // Player
  static const double playerRadius = 8.0; 
  static const double playerFriction = 10.0; // Ma sát cực cao để dừng ngay lập tức
  
  // Multiplayer
  static const int syncIntervalMs = 50;
  
  // Assets
  static const double tileSize = 18.0;
}