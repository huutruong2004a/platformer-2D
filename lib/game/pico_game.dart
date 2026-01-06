import 'package:flame/components.dart' hide Vector2;
import 'package:flame/events.dart';
import 'package:flame/game.dart' hide Vector2;
import 'package:flame/camera.dart'; 
import 'package:flame/input.dart'; 
import 'package:flame/palette.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui'; // For lerpDouble
import '../data/supabase_service.dart'; // Import Service
import 'pico_world.dart';
import '../core/constants/game_config.dart';
import 'mixins/pico_controls.dart';
import 'components/player/player.dart';

class PicoGame extends Forge2DGame with HasKeyboardHandlerComponents, PicoControls {
  final String levelId;
  final SupabaseService? supabaseService;
  // Mutable player list to track current room members
  List<String> players = [];
  final String? currentUserId;
  
  // Locking flag to prevent race conditions during level load/reset
  bool _isLevelLoading = false;
  
  // Game Logic
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int totalCoinsInLevel = 0;
  
  // Map size for camera bounds (set by LevelLoader)
  Vector2 mapSize = Vector2(800, 600); // Default, will be updated
  Vector2? currentLevelSpawnPoint; // Set by LevelLoader
  
  // Multiplayer Flag Tracking
  final Set<String> playersAtFlag = {};

  PicoGame({
    required this.levelId, 
    this.supabaseService,
    List<String>? players,
    this.currentUserId,
  }) : super(
        gravity: GameConfig.gravity,
        camera: CameraComponent.withFixedResolution(width: 640, height: 360),
      ) {
    if (players != null) {
      this.players.addAll(players);
      this.players.sort(); // Ensure consistent order initially
    }
  }

  @override
  Future<void> onLoad() async {
    _isLevelLoading = true; // Start loading lock
    scoreNotifier.value = 0;
    playersAtFlag.clear();
    
    final world = PicoWorld(currentLevelId: levelId);
    this.world = world;

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = 1.5; // Fix zoom 1.5 như bản ổn định
    
    // Setup Multiplayer Callbacks
    _setupMultiplayerCallbacks();

    debugMode = false;
    await super.onLoad();

    if (isMobilePlatform()) {
      addMobileControls();
    }
    // Note: onLevelLoaded will be called by LevelLoader when map is ready
  }
  
  void onLevelLoaded() {
    _isLevelLoading = false;
    print('Level Loaded. Unlocking spawn logic. Players: ${players.length}');
    
    // Spawn pending players now that map is ready
    if (players.isNotEmpty) {
      // Ensure sorted before spawning
      players.sort();
      _spawnPlayers();
    }
  }
  
  void _setupMultiplayerCallbacks() {
    if (supabaseService == null) return;
    
    // Clear old callbacks from previous level/game instance
    supabaseService!.clearGameCallbacks();
    
    // Position sync
    supabaseService!.setGameMoveCallback(onRemoteMove);
    
    // Coin collected by others
    supabaseService!.setCoinCollectedCallback((coinId) {
      onRemoteCoinCollected(coinId);
    });
    
    // Level reset (someone died)
    supabaseService!.setLevelResetCallback(() {
      resetLevel(broadcast: false); // Don't re-broadcast
    });
    
    // Player at flag
    supabaseService!.setPlayerAtFlagCallback((playerId) {
      onRemotePlayerAtFlag(playerId);
    });
    
    // Listen for new players joining
    supabaseService!.setPresenceSyncCallback((newPlayerIds) {
      _handlePresenceUpdate(newPlayerIds);
    });
  }
  
  // Track spawned players to avoid duplicates
  final Set<String> _spawnedPlayerIds = {};
  
  void _handlePresenceUpdate(List<String> playerIds) {
    // Update local list
    players.clear();
    players.addAll(playerIds);
    players.sort(); // SORTING IS CRITICAL FOR SYNC

    // If level is loading, DO NOT spawn anyone yet. 
    // LevelLoader will handle initial spawns based on 'players' list or map data.
    if (_isLevelLoading) return;

    // Trigger spawn for any unspawned players
    _spawnPlayers();
  }
  
  // Public method for LevelLoader to register spawned players
  void markPlayerAsSpawned(String playerId) {
    _spawnedPlayerIds.add(playerId);
  }

  // Centralized Spawn Logic
  void _spawnPlayers() {
     if (currentLevelSpawnPoint == null) {
       print("Cannot spawn players: No spawn point set.");
       return;
     }
     
     // Robust loop to handle list updates
     for (int i = 0; i < players.length; i++) {
       final playerId = players[i];
       
       // Skip if already spawned
       if (_spawnedPlayerIds.contains(playerId)) continue;
       
       _spawnedPlayerIds.add(playerId);
       
       final isMe = playerId == currentUserId;
       
       // Calculate position based on index (sorted)
       final spawnPos = currentLevelSpawnPoint! + Vector2(i * 10.0, 0); 
       
       final player = Player(
         initialPosition: spawnPos,
         isControllable: isMe,
         skinIndex: i, // Index determines skin
       );
       
       world.add(player);
       print('Spawned Player: $playerId (Me: $isMe) at Index $i');
     }
  }

  // Multiplayer Sync
  double _lastBroadcastTime = 0;
  
  @override
  void update(double dt) {
    super.update(dt);
    _handleMultiplayerSync(dt);
    _updateCamera(dt);
  }

  void _updateCamera(double dt) {
    // 1. Find the Local Player (My Character)
    try {
      final player = world.children.query<Player>().firstWhere((p) => p.isControllable);
      
      // 2. Target Position (Center on Player)
      final targetPos = player.body.position;
      
      // 3. Clamp camera to map bounds
      final viewportSize = camera.viewport.virtualSize;
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
      
      // 4. Smooth Follow (Manual Lerp - Proven Smoother)
      final currentPos = camera.viewfinder.position;
      final newPos = currentPos + (Vector2(clampedX, clampedY) - currentPos) * (dt * 5.0);
      
      camera.viewfinder.position = newPos;

    } catch (e) {
      // Player might not be spawned yet
    }
  }

  void _handleMultiplayerSync(double dt) {
    if (supabaseService == null || currentUserId == null) return;

    // 1. BROADCAST (Gửi vị trí của mình)
    _lastBroadcastTime += dt;
    if (_lastBroadcastTime >= 0.05) { // 50ms (20 lần/giây)
      _lastBroadcastTime = 0;
      
      // Tìm nhân vật của mình (isControllable = true)
      try {
        final myPlayer = world.children.query<Player>().firstWhere((p) => p.isControllable);
        final pos = myPlayer.body.position;
        final vel = myPlayer.body.linearVelocity;
        
        supabaseService!.broadcastPosition(
          x: pos.x,
          y: pos.y,
          velocityX: vel.x,
          velocityY: vel.y,
          isFlipped: myPlayer.spriteComponent.scale.x < 0,
        );
      } catch (e) {
        // Player chưa spawn hoặc đã chết
      }
    }
  }



  void onRemoteMove(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final xRaw = data['x'];
    final yRaw = data['y'];
    final vxRaw = data['vx'];
    final vyRaw = data['vy'];
    
    // Null safety check
    if (id == null || xRaw == null || yRaw == null) {
      print('Invalid move data: $data');
      return;
    }
    
    final x = (xRaw as num).toDouble();
    final y = (yRaw as num).toDouble();
    final vx = (vxRaw as num?)?.toDouble() ?? 0.0;
    final vy = (vyRaw as num?)?.toDouble() ?? 0.0;
    
    // Tìm Player Entity tương ứng
    if (!players.contains(id)) {
       // SELF-HEALING: Player sent data but is not in list (Presence Sync failed/lagged)
       print("Self-Healing: Found unknown player $id active in game. Adding...");
       players.add(id);
       players.sort();
       _spawnPlayers();
    }
    
    final index = players.indexOf(id);
    
    final playerComponents = world.children.query<Player>();
    for (final p in playerComponents) {
      if (!p.isControllable && p.skinIndex == index) {
        p.updateStateFromServer(x, y, vx, vy);
        break;
      }
    }
  }

  // ... (Giữ nguyên các hàm Mobile Controls)
  bool isMobilePlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS;
  }
  
  // addMobileControls is now provided by PicoControls mixin


  // === COIN SYSTEM ===
  // Map để track coins theo ID (dùng vị trí làm ID)
  final Map<String, dynamic> _coinRegistry = {};
  
  void registerCoin(String coinId, dynamic coin) {
    _coinRegistry[coinId] = coin;
  }
  
  void addCoin({String? coinId, bool broadcast = true}) {
    scoreNotifier.value++;
    print('Coins: ${scoreNotifier.value} / $totalCoinsInLevel');
    
    // Broadcast to others if this is local collection
    if (broadcast && coinId != null && supabaseService != null) {
      supabaseService!.broadcastCoinCollected(coinId);
    }
  }
  
  void onRemoteCoinCollected(String coinId) {
    // Remove coin from world
    final coin = _coinRegistry[coinId];
    if (coin != null) {
      coin.removeFromParent();
      _coinRegistry.remove(coinId);
      // IMPORTANT: Increment SHARED score locally when remote player collects coin
      scoreNotifier.value++; 
      print('Remote coin collected: $coinId. Total Score: ${scoreNotifier.value}');
    }
  }

  // === RESET SYSTEM ===
  void resetLevel({bool broadcast = true}) {
    // Debounce: If already loading/resetting, ignore this call
    if (_isLevelLoading) {
      print('Ignored duplicate resetLevel call.');
      return;
    }
  
    _isLevelLoading = true; // Lock spawn system
    scoreNotifier.value = 0;
    playersAtFlag.clear();
    _spawnedPlayerIds.clear(); // Clear to prevent duplication on respawn
    _coinRegistry.clear(); // Clear coin registry
    
    remove(world);
    final newWorld = PicoWorld(currentLevelId: levelId);
    world = newWorld;
    add(newWorld);
    camera.viewfinder.zoom = 1.0;
    camera.viewfinder.anchor = Anchor.center;
    
    // Reset mobile control states
    isLeftPressed = false;
    isRightPressed = false;
    isJumpPressed = false;
    
    print('Level Reset!');
    // Note: onLevelLoaded will unlock _isLevelLoading
    
    // Broadcast to others
    if (broadcast && supabaseService != null) {
      supabaseService!.broadcastLevelReset();
    }
  }
  
  // Called when player dies (from Trap)
  void onPlayerDied() {
    resetLevel(broadcast: true);
  }

  // === FLAG/WIN SYSTEM ===
  // === FLAG/WIN SYSTEM ===
  void onPlayerAtFlag({bool broadcast = true}) {
    // Fallback ID for Single Player
    final playerId = currentUserId ?? 'local_player';
    
    // Chặn Spam: Nếu đã chạm rồi thì thôi, không gửi tin nhắn nữa
    if (playersAtFlag.contains(playerId)) return;
    
    playersAtFlag.add(playerId);
    final total = players.isEmpty ? 1 : players.length;
    print('Player at flag: $playerId. Total: ${playersAtFlag.length}/$total');
    
    if (broadcast && supabaseService != null && currentUserId != null) {
      supabaseService!.broadcastPlayerAtFlag();
    }
    
    checkLevelCompletion();
  }
  
  void onRemotePlayerAtFlag(String playerId) {
    // SELF-HEALING check
    if (!players.contains(playerId)) {
       players.add(playerId);
       players.sort();
       _spawnPlayers();
    }
    playersAtFlag.add(playerId);
    print('Remote player at flag: $playerId. Total: ${playersAtFlag.length}/${players.length}');
    checkLevelCompletion();
  }

  void checkLevelCompletion() {
    // Ensure totalPlayers is at least 1 and consistent with room state
    final totalPlayers = players.isEmpty ? 1 : players.length;
    
    // Debug log to trace why it might fail
    print("Checking Win Condition: At Flag: ${playersAtFlag.length} / Total: $totalPlayers");
    print("Players at flag: $playersAtFlag");
    print("All Players: $players");

    // All players must be at flag
    if (playersAtFlag.length >= totalPlayers) {
      print('LEVEL COMPLETED! All $totalPlayers players at flag!');
      pauseEngine(); 
      overlays.add('LevelComplete'); 
    } else {
      final remaining = totalPlayers - playersAtFlag.length;
      // Show toast or HUD message?
      print('Waiting for $remaining more players at flag...');
    }
  }
}

