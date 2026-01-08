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
  SupabaseService? supabaseService; // Changed from final
  // Mutable player list to track current room members
  List<String> players = [];
  // Map UserId -> SkinIndex for visual sync
  Map<String, int> playerSkins; // Changed from final
  String? currentUserId; // Changed from final
  
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
  
  // Player Registry for fast lookup by userId
  final Map<String, Player> _playerRegistry = {};
  
  // Buffer for moves received before map loads
  final List<Map<String, dynamic>> _pendingMoves = [];

  PicoGame({
    required this.levelId, 
    this.supabaseService,
    List<String>? players,
    this.currentUserId,
    Map<String, int>? playerSkins,
  }) : playerSkins = playerSkins ?? {},
       super(
        gravity: GameConfig.gravity,
        camera: CameraComponent.withFixedResolution(width: 640, height: 360),
      ) {
    if (players != null) {
      this.players.addAll(players);
      this.players.sort(); // Ensure consistent order initially
    }
  }
  
  // Method to update game state when joining a room in Lobby
  void updateLobbyState({
    required SupabaseService service,
    required List<String> players,
    required String currentUserId,
    required Map<String, int> skins,
  }) {
    print("PicoGame: Updating Lobby State. Players: ${players.length}");
    this.supabaseService = service;
    this.currentUserId = currentUserId;
    this.playerSkins = skins;
    
    // Update player list
    this.players.clear();
    this.players.addAll(players);
    this.players.sort();
    
    // Setup callbacks with new service
    _setupMultiplayerCallbacks();
    
    // Trigger Spawn
    // Clear existing players first
    for (final p in _playerRegistry.values) {
      p.removeFromParent();
    }
    _playerRegistry.clear();
    _spawnedPlayerIds.clear();
    
    _spawnPlayers();
  }

  @override
  Future<void> onLoad() async {
    _isLevelLoading = true; // Start loading lock
    scoreNotifier.value = 0;
    playersAtFlag.clear();
    
    final world = PicoWorld(currentLevelId: levelId);
    this.world = world;

    camera.viewfinder.anchor = Anchor.center;
    // Zoom Logic: Lobby needs wider view (1.5), Game Levels need zoom (2.0)
    if (levelId.contains('lobby')) {
      camera.viewfinder.zoom = 1.5;
    } else {
      camera.viewfinder.zoom = 2.0; 
    }
    
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
    
    // Process buffered moves that arrived during loading
    if (_pendingMoves.isNotEmpty) {
      print('Processing ${_pendingMoves.length} buffered moves');
      for (final move in _pendingMoves) {
        _processRemoteMove(move);
      }
      _pendingMoves.clear();
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
    
    // Listen for Skin Updates
    supabaseService!.setSkinUpdateCallback((userId, skinIndex) {
      onSkinUpdate(userId, skinIndex);
    });
  }
  
  // Handle visual update when someone changes skin in lobby
  void onSkinUpdate(String userId, int skinIndex) {
    print("Game received Skin Update: $userId -> $skinIndex");
    playerSkins[userId] = skinIndex;
    
    // If player exists, update their appearance immediately (if supported by Player component)
    // For now, we might need to recreate the player or add a method to update sprite
    final player = _playerRegistry[userId];
    if (player != null) {
      // TODO: Implement dynamic skin update in Player component
      // For now, removing and re-adding is a brute-force way, or just update next spawn
      // Ideally Player has updateSkin() method.
      // Since Player loads sprite in onLoad, we can't just change a property easily without reload logic.
      // But we can swap the SpriteComponent.
      
      // Better approach: Restart level if in lobby to refresh? No, that resets position.
      // Let's just update the map for now. The next spawn will be correct.
      // If we want real-time update in lobby without respawn:
      // We need to implement swapSkin() in Player.
    }
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
       final spawnPos = currentLevelSpawnPoint! + Vector2(i * 20.0, 0); 
       
       // Determine Skin: Use Map if available, else fallback to Index
       final skinIdx = playerSkins[playerId] ?? i;
       
       final player = Player(
         initialPosition: spawnPos,
         isControllable: isMe,
         skinIndex: skinIdx, // Correct Skin Index
         playerId: playerId, // Store player ID for sync
       );
       
       // Register player for fast lookup
       _playerRegistry[playerId] = player;
       
       world.add(player);
       print('Spawned Player: $playerId (Me: $isMe) at Index $i (Skin $skinIdx), Pos: $spawnPos');
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
    // LOBBY CAMERA: Static, centered
    if (levelId.contains('lobby')) {
      camera.viewfinder.position = Vector2(mapSize.x / 2, mapSize.y / 2);
      return;
    }

    final viewportSize = camera.viewport.virtualSize;
    final currentZoom = camera.viewfinder.zoom;
    
    final mapWidth = mapSize.x;
    final mapHeight = mapSize.y;
    
    // Calculate half view size in world coordinates
    final halfViewWidth = viewportSize.x / (2 * currentZoom);
    final halfViewHeight = viewportSize.y / (2 * currentZoom);
    
    Vector2 targetPos;
    
    // 1. Try to find the Local Player
    try {
      final player = world.children.query<Player>().firstWhere((p) => p.isControllable);
      targetPos = player.body.position;
    } catch (e) {
      // No player spawned yet - center camera on map
      targetPos = Vector2(mapWidth / 2, mapHeight / 2);
    }

    double clampedX = targetPos.x;
    double clampedY = targetPos.y;

    // Clamp to map bounds
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
    
    // Smooth Follow
    final currentPos = camera.viewfinder.position;
    final newPos = currentPos + (Vector2(clampedX, clampedY) - currentPos) * (dt * 5.0);
    
    camera.viewfinder.position = newPos;
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
    // If level is still loading, buffer the move for later processing
    if (_isLevelLoading) {
      _pendingMoves.add(data);
      return;
    }
    
    _processRemoteMove(data);
  }
  
  // Actual move processing logic (called directly or from buffer)
  void _processRemoteMove(Map<String, dynamic> data) {
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
    
    // Self-healing: Add player if not in list
    if (!players.contains(id)) {
       print("Self-Healing: Found unknown player $id active in game. Adding...");
       players.add(id);
       players.sort();
       _spawnPlayers();
    }
    
    // Use Player Registry for fast lookup
    final player = _playerRegistry[id];
    if (player != null && !player.isControllable) {
      player.updateStateFromServer(x, y, vx, vy);
    } else if (player == null) {
      // Player not yet spawned, queue a spawn attempt
      print("Player $id not in registry, attempting spawn...");
      _spawnPlayers();
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
    _playerRegistry.clear(); // Clear player registry for fresh spawn
    
    remove(world);
    final newWorld = PicoWorld(currentLevelId: levelId);
    world = newWorld;
    add(newWorld);
    
    // Reset Zoom
    if (levelId.contains('lobby')) {
      camera.viewfinder.zoom = 1.5;
    } else {
      camera.viewfinder.zoom = 2.0;
    }
    
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
    print("Checking Win Condition: At Flag: ${playersAtFlag.length} / Total: $totalPlayers, Coins: ${scoreNotifier.value}/3");
    print("Players at flag: $playersAtFlag");
    print("All Players: $players");

    // MULTIPLAYER WIN CONDITION:
    // 1. Team must collect AT LEAST 3 coins (shared score)
    // 2. ALL players must touch the flag (can be sequential, not simultaneous)
    final requiredCoins = 3;
    
    if (scoreNotifier.value < requiredCoins) {
      print('Need ${requiredCoins - scoreNotifier.value} more coins to complete level!');
      return;
    }
    
    // All players must be at flag
    if (playersAtFlag.length >= totalPlayers) {
      print('LEVEL COMPLETED! All $totalPlayers players at flag with ${scoreNotifier.value} coins!');
      pauseEngine(); 
      overlays.add('LevelComplete'); 
    } else {
      final remaining = totalPlayers - playersAtFlag.length;
      print('Waiting for $remaining more players at flag...');
    }
  }
}

