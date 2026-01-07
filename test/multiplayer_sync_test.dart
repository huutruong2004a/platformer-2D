import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platformer_2d/game/components/player/player.dart';

/// Unit tests for multiplayer synchronization logic
/// These tests verify the core sync mechanisms without requiring a running game
void main() {
  group('Player Component Tests', () {
    test('Player should be created with playerId', () {
      final player = Player(
        initialPosition: Vector2(100, 100),
        isControllable: true,
        skinIndex: 0,
        playerId: 'test-user-123',
      );
      
      expect(player.playerId, 'test-user-123');
      expect(player.skinIndex, 0);
      expect(player.isControllable, true);
    });
    
    test('Player should have default playerId for single player', () {
      final player = Player(
        initialPosition: Vector2(100, 100),
        isControllable: true,
      );
      
      expect(player.playerId, 'local_player');
    });
    
    test('Remote player should not be controllable', () {
      final remotePlayer = Player(
        initialPosition: Vector2(200, 100),
        isControllable: false,
        skinIndex: 1,
        playerId: 'remote-user-456',
      );
      
      expect(remotePlayer.isControllable, false);
      expect(remotePlayer.playerId, 'remote-user-456');
    });
  });
  
  group('MoveSnapshot Tests', () {
    test('MoveSnapshot should store position and velocity', () {
      final snapshot = MoveSnapshot(
        Vector2(100.0, 200.0),
        Vector2(50.0, -30.0),
        DateTime.now(),
      );
      
      expect(snapshot.position.x, 100.0);
      expect(snapshot.position.y, 200.0);
      expect(snapshot.velocity.x, 50.0);
      expect(snapshot.velocity.y, -30.0);
    });
    
    test('MoveSnapshot timestamp should be set', () {
      final now = DateTime.now();
      final snapshot = MoveSnapshot(
        Vector2.zero(),
        Vector2.zero(),
        now,
      );
      
      expect(snapshot.timestamp, now);
    });
  });
  
  group('Player Registry Logic Tests', () {
    test('Sorted player list should be consistent', () {
      final players = ['user-c', 'user-a', 'user-b'];
      players.sort();
      
      expect(players[0], 'user-a');
      expect(players[1], 'user-b');
      expect(players[2], 'user-c');
    });
    
    test('Player index should match after sort', () {
      final players = ['user-c', 'user-a', 'user-b'];
      players.sort();
      
      // After sorting, index determines skinIndex
      expect(players.indexOf('user-a'), 0);
      expect(players.indexOf('user-b'), 1);
      expect(players.indexOf('user-c'), 2);
    });
    
    test('Player registry map should store and retrieve players', () {
      final registry = <String, Player>{};
      
      final p1 = Player(
        initialPosition: Vector2(0, 0),
        playerId: 'user-a',
        skinIndex: 0,
      );
      
      final p2 = Player(
        initialPosition: Vector2(20, 0),
        playerId: 'user-b',
        skinIndex: 1,
        isControllable: false,
      );
      
      registry['user-a'] = p1;
      registry['user-b'] = p2;
      
      expect(registry['user-a'], p1);
      expect(registry['user-b'], p2);
      expect(registry['user-c'], null);
    });
  });
  
  group('Spawn Position Logic Tests', () {
    test('Spawn positions should be spaced correctly', () {
      final spawnPoint = Vector2(100, 200);
      final spacing = 20.0;
      
      for (int i = 0; i < 4; i++) {
        final pos = spawnPoint + Vector2(i * spacing, 0);
        expect(pos.x, 100 + i * 20);
        expect(pos.y, 200);
      }
    });
  });
  
  group('Move Data Parsing Tests', () {
    test('Should parse valid move data', () {
      final data = {
        'id': 'user-123',
        'x': 150.5,
        'y': 200.0,
        'vx': 10.0,
        'vy': -5.0,
      };
      
      final id = data['id'] as String?;
      final x = (data['x'] as num?)?.toDouble();
      final y = (data['y'] as num?)?.toDouble();
      final vx = (data['vx'] as num?)?.toDouble() ?? 0.0;
      final vy = (data['vy'] as num?)?.toDouble() ?? 0.0;
      
      expect(id, 'user-123');
      expect(x, 150.5);
      expect(y, 200.0);
      expect(vx, 10.0);
      expect(vy, -5.0);
    });
    
    test('Should handle missing velocity data', () {
      final data = {
        'id': 'user-123',
        'x': 150,
        'y': 200,
      };
      
      final vx = (data['vx'] as num?)?.toDouble() ?? 0.0;
      final vy = (data['vy'] as num?)?.toDouble() ?? 0.0;
      
      expect(vx, 0.0);
      expect(vy, 0.0);
    });
    
    test('Should handle integer coordinates', () {
      final data = {
        'id': 'user-123',
        'x': 150,
        'y': 200,
      };
      
      final x = (data['x'] as num).toDouble();
      final y = (data['y'] as num).toDouble();
      
      expect(x, 150.0);
      expect(y, 200.0);
    });
  });
  
  group('Presence Sync Tests', () {
    test('Should detect new players', () {
      final oldPlayers = ['user-a', 'user-b'];
      final newPlayers = ['user-a', 'user-b', 'user-c'];
      
      final newOnes = newPlayers.where((p) => !oldPlayers.contains(p)).toList();
      
      expect(newOnes.length, 1);
      expect(newOnes.first, 'user-c');
    });
    
    test('Should detect left players', () {
      final oldPlayers = ['user-a', 'user-b', 'user-c'];
      final newPlayers = ['user-a', 'user-c'];
      
      final leftOnes = oldPlayers.where((p) => !newPlayers.contains(p)).toList();
      
      expect(leftOnes.length, 1);
      expect(leftOnes.first, 'user-b');
    });
  });
}
