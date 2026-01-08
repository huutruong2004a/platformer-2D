import 'package:flame/components.dart';
import 'package:flame/experimental.dart'; // Use Flame's experimental Rectangle
import 'package:flame_tiled/flame_tiled.dart';
import 'package:tiled/tiled.dart'; // Explicit import for Gid/Flips
import 'package:flame/game.dart';
import '../../pico_game.dart';
import '../../pico_game_single.dart';
import '../../../core/constants/game_config.dart';
import 'ground.dart';
import '../player/player.dart';
import '../objects/coin.dart';
import '../objects/trap.dart';
import '../objects/flag.dart';
import 'package:flame_forge2d/flame_forge2d.dart'; // Added for Forge2DWorld

class LevelLoader extends Component with HasGameRef<Forge2DGame> {
  final String levelName;
  final Forge2DWorld worldRef; // Added worldRef

  LevelLoader({required this.levelName, required this.worldRef}); // Modified constructor

  @override
  Future<void> onLoad() async {
    try {
      print('LevelLoader: Loading map $levelName...');
      // Load map from assets/tiles/
      final map = await TiledComponent.load(
        '$levelName.tmx',
        Vector2.all(GameConfig.tileSize),
      );
      map.position = Vector2.zero(); // Đảm bảo map bắt đầu từ 0,0
      add(map);
      print('LevelLoader: Map loaded successfully.');

      // Set Camera Bounds để không nhìn ra ngoài map
      // Skip for Lobby (map might be smaller than viewport)
      if (!levelName.contains('lobby')) {
        final mapWidth = map.tileMap.map.width * map.tileMap.map.tileWidth.toDouble();
        final mapHeight = map.tileMap.map.height * map.tileMap.map.tileHeight.toDouble();
        final mapRect = Rectangle.fromLTWH(0, 0, mapWidth, mapHeight);
        gameRef.camera.setBounds(mapRect);
        
        // Update map size for dynamic camera clamping (Dynamic Access)
        if (gameRef is PicoGame) (gameRef as PicoGame).mapSize = Vector2(mapWidth, mapHeight);
        if (gameRef is PicoGameSingle) (gameRef as PicoGameSingle).mapSize = Vector2(mapWidth, mapHeight);
      } else {
         // Just update map size for Lobby
        final mapWidth = map.tileMap.map.width * map.tileMap.map.tileWidth.toDouble();
        final mapHeight = map.tileMap.map.height * map.tileMap.map.tileHeight.toDouble();
        if (gameRef is PicoGame) (gameRef as PicoGame).mapSize = Vector2(mapWidth, mapHeight);
      }
      
      // Đếm tổng số coin
      int coinCount = 0;

      // Parse Objects từ Layer 'Ground'
      _parseLayer(map, 'Ground', (obj) => GroundBody(obj.x, obj.y, obj.width, obj.height));
      
      _parseLayer(map, 'Trap', (obj) => Trap(
        position: Vector2(obj.x + obj.width / 2, obj.y + obj.height / 2),
        size: Vector2(obj.width, obj.height)
      ));
      
      _parseLayer(map, 'Flag', (obj) => Flag(
        position: Vector2(obj.x + obj.width / 2, obj.y + obj.height / 2),
        size: Vector2(obj.width, obj.height)
      ));
      
      _parseLayer(map, 'Hole', (obj) => Trap(
        position: Vector2(obj.x + obj.width / 2, obj.y + obj.height / 2),
        size: Vector2(obj.width, obj.height)
      ));

      // Coin is a Tile Object (Bottom-Left origin in Tiled).
      _parseLayer(map, 'Coin', (obj) {
        coinCount++;
        return Coin(
          position: Vector2(obj.x, obj.y - obj.height),
          size: Vector2(obj.width, obj.height)
        );
      });

      // Ẩn các layer tĩnh
      final coinLayer = map.tileMap.getLayer('Coin');
      if (coinLayer != null) coinLayer.visible = false;
      
      final flagLayer = map.tileMap.getLayer('Flag');
      if (flagLayer != null) flagLayer.visible = false;
      
      final trapLayer = map.tileMap.getLayer('Trap');
      if (trapLayer != null) trapLayer.visible = false;
      
      final holeLayer = map.tileMap.getLayer('Hole');
      if (holeLayer != null) holeLayer.visible = false;

      // Cập nhật tổng số coin cho Game (Dynamic Access)
      if (gameRef is PicoGame) {
        (gameRef as PicoGame).totalCoinsInLevel = coinCount;
        (gameRef as PicoGame).scoreNotifier.value = 0;
      } else if (gameRef is PicoGameSingle) {
        (gameRef as PicoGameSingle).totalCoinsInLevel = coinCount;
        (gameRef as PicoGameSingle).scoreNotifier.value = 0;
      }
      
      // === SPAWN PLAYERS LOGIC ===
      var spawnLayer = map.tileMap.getLayer<ObjectGroup>('SpawnPoint');
      if (spawnLayer == null) {
        spawnLayer = map.tileMap.getLayer<ObjectGroup>('SpawnPoints');
      }

      double spawnX = 100;
      double spawnY = 100;

      if (spawnLayer != null && spawnLayer.objects.isNotEmpty) {
        final p1 = spawnLayer.objects.first;
        spawnX = p1.x + (p1.width / 2);
        // Y: Align player feet (approx 11px from center) to bottom of spawn rect
        // This ensures player stands ON the ground, not inside it.
        spawnY = p1.y + p1.height - 11;
        print("LevelLoader: Found Spawn Point at $spawnX, $spawnY");
      } else {
        print("LevelLoader: WARNING - No SpawnPoint layer found!");
      }
      
      // Save Spawn Point for late-joining players (Multiplayer Only)
      if (gameRef is PicoGame) {
        (gameRef as PicoGame).currentLevelSpawnPoint = Vector2(spawnX, spawnY);
      }
      
      // Logic Spawn
      if (gameRef is PicoGame) {
        // --- MULTIPLAYER ---
        // Do nothing here. PicoGame will handle spawning in onLevelLoaded()
        // using the confirmed player list from Supabase.
      } else {
        // --- SINGLE PLAYER ---
        _spawnSinglePlayer(spawnX, spawnY);
      }

      print('LevelLoader finished loading map: $levelName');
      
      if (gameRef is PicoGame) (gameRef as PicoGame).onLevelLoaded();
      if (gameRef is PicoGameSingle) (gameRef as PicoGameSingle).onLevelLoaded();
      
    } catch (e, stack) {
      print('LevelLoader ERROR: $e');
      print(stack);
    }
  }
  
  Future<void> _spawnSinglePlayer(double x, double y) async {
     final player = Player(
       initialPosition: Vector2(x, y),
       isControllable: true,
       skinIndex: 0,
       playerId: 'local_player',
     );
     await worldRef.add(player);
  }

  void _parseLayer(TiledComponent map, String layerName, Component Function(TiledObject) factory) {
    final layer = map.tileMap.getLayer<ObjectGroup>(layerName);
    
    if (layer != null) {
      for (final object in layer.objects) {
        add(factory(object));
      }
    }
  }
}