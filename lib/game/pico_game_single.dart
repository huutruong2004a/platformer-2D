import 'package:flame/components.dart' hide Vector2;
import 'package:flame/events.dart';
import 'package:flame/game.dart' hide Vector2;
import 'package:flame/camera.dart'; 
import 'package:flame/input.dart'; 
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'dart:math';
import 'pico_world.dart';
import '../core/constants/game_config.dart';
import 'mixins/pico_controls.dart';
import 'components/player/player.dart';

class PicoGameSingle extends Forge2DGame with HasKeyboardHandlerComponents, PicoControls {
  final String levelId;
  
  // Game Logic
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int totalCoinsInLevel = 0;
  
  // Map size for camera bounds (set by LevelLoader)
  Vector2 mapSize = Vector2(800, 600); 
  
  // Single Player Flag Tracking
  bool isPlayerAtFlag = false;

  PicoGameSingle({
    required this.levelId, 
  }) : super(
        gravity: GameConfig.gravity,
        camera: CameraComponent.withFixedResolution(width: 640, height: 360),
      );

  @override
  Future<void> onLoad() async {
    scoreNotifier.value = 0;
    isPlayerAtFlag = false;
    
    final world = PicoWorld(currentLevelId: levelId);
    this.world = world;

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = 2.5; // Fix zoom 2.5 cho dễ nhìn
    
    debugMode = false;
    await super.onLoad();

    if (isMobilePlatform()) {
      addMobileControls();
    }
  }
  
  void onLevelLoaded() {
    print('Single Player Level Loaded.');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateCamera(dt);
  }

  void _updateCamera(double dt) {
    // 1. Find the Player
    try {
      final player = world.children.query<Player>().firstWhere((p) => p.isControllable);
      
      // 2. Target Position (Center on Player)
      final targetPos = player.body.position;
      
      // 3. Clamp camera to map bounds
      final viewportSize = camera.viewport.virtualSize;
      // Use fixed zoom
      final currentZoom = camera.viewfinder.zoom; 
      
      final mapWidth = mapSize.x;
      final mapHeight = mapSize.y;
      
      // Calculate half view size in world coordinates
      final halfViewWidth = viewportSize.x / (2 * currentZoom);
      final halfViewHeight = viewportSize.y / (2 * currentZoom);

      double clampedX = targetPos.x;
      double clampedY = targetPos.y;

      // Only clamp if map is larger than viewport
      if (mapWidth > halfViewWidth * 2) {
        clampedX = clampedX.clamp(halfViewWidth, mapWidth - halfViewWidth);
      } else {
        clampedX = mapWidth / 2;
      }

      if (mapHeight > halfViewHeight * 2) {
        clampedY = clampedY.clamp(halfViewHeight, mapHeight - halfViewHeight);
      } else {
        clampedY = mapHeight / 2;
      }
      
      // 4. Smooth Follow
      final currentPos = camera.viewfinder.position;
      final newPos = currentPos + (Vector2(clampedX, clampedY) - currentPos) * (dt * 5.0);
      
      camera.viewfinder.position = newPos;

    } catch (e) {
      // Player might not be spawned yet
    }
  }

  // ... (Mobile Controls - Same as PicoGame)
  bool isMobilePlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS;
  }
  
  // addMobileControls provided by mixin


  // === COIN SYSTEM ===
  final Map<String, dynamic> _coinRegistry = {};
  
  void registerCoin(String coinId, dynamic coin) {
    _coinRegistry[coinId] = coin;
  }
  
  void addCoin({String? coinId, bool broadcast = true}) {
    // In Single Player, broadcast is ignored
    scoreNotifier.value++;
    print('Single Player Coins: ${scoreNotifier.value} / $totalCoinsInLevel');
  }

  // === RESET SYSTEM ===
  void resetLevel({bool broadcast = true}) {
    scoreNotifier.value = 0;
    isPlayerAtFlag = false;
    _coinRegistry.clear();
    
    remove(world);
    final newWorld = PicoWorld(currentLevelId: levelId);
    world = newWorld;
    add(newWorld);
    
    // Reset mobile control states
    isLeftPressed = false;
    isRightPressed = false;
    isJumpPressed = false;
    
    print('Single Player Level Reset!');
  }
  
  void onPlayerDied() {
    resetLevel();
  }

  // === FLAG/WIN SYSTEM ===
  void onPlayerAtFlag({bool broadcast = true}) {
    if (!isPlayerAtFlag) {
      isPlayerAtFlag = true;
      print('Single Player Level Complete!');
      pauseEngine();
      overlays.add('LevelComplete');
    }
  }
  
  // Dummy methods to satisfy interface if components share code
  void markPlayerAsSpawned(String id) {} 
}
