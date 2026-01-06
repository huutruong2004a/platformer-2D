import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _roomChannel;
  // List of callbacks (Multi-listener pattern)
  final List<Function(Map<String, dynamic>)> _gameMoveCallbacks = [];
  final List<Function(String, int)> _skinUpdateCallbacks = [];
  final List<Function(List<String>)> _presenceSyncCallbacks = [];
  final List<Function(String)> _coinCollectedCallbacks = [];
  final List<Function()> _levelResetCallbacks = [];
  final List<Function(String)> _playerAtFlagCallbacks = [];
  final List<Function(String)> _startGameCallbacks = [];

  // Getter lấy User ID
  String? get currentUserId => _client.auth.currentUser?.id;

  // Đăng ký callbacks (Add instead of Set)
  void addGameMoveCallback(Function(Map<String, dynamic>) callback) => _gameMoveCallbacks.add(callback);
  void addSkinUpdateCallback(Function(String, int) callback) => _skinUpdateCallbacks.add(callback);
  void addPresenceSyncCallback(Function(List<String>) callback) => _presenceSyncCallbacks.add(callback);
  void addCoinCollectedCallback(Function(String) callback) => _coinCollectedCallbacks.add(callback);
  void addLevelResetCallback(Function() callback) => _levelResetCallbacks.add(callback);
  void addPlayerAtFlagCallback(Function(String) callback) => _playerAtFlagCallbacks.add(callback);
  void addStartGameCallback(Function(String) callback) => _startGameCallbacks.add(callback);
  
  // Backward compatibility methods (Deprecating 'set' but keeping logic for now or replacing it)
  // To avoid breaking existing code immediately, we can make 'set' alias to 'add' (clearing old? No, add is safer for now).
  // But wait, if we use 'set' alias to 'add', we pile up listeners if called repeatedly (e.g. creating multiple PicoGames).
  // For now, let's REPLACE 'set' with logic: Clear + Add? No, that breaks multi-listener goal.
  // Best approach: Rename 'set' to 'add' in usage sites (RoomProvider, PicoGame).
  // But to be safe in this edit, I will rename variables and update the dispatch logic to loop through lists.
  
  // Re-implementing 'set' as 'add' for compatibility (User requested fix, not full refactor of codebase yet).
  // WARNING: If `set` is called multiple times, it adds more. 
  // Ideally we should have `removeCallback`, but anonymous functions are hard to remove.
  // Given the lifecycle (`RoomProvider` lives forever, `PicoGame` lives in GameWidget), `PicoGame` might pile up listeners if recreated?
  // `PicoGame` is created in `LobbyScreen._getOrCreateGame` and cached. So it's created ONCE per lobby session.
  // So 'add' is fine.
  
  void setGameMoveCallback(Function(Map<String, dynamic>) callback) => _gameMoveCallbacks.add(callback);
  void setSkinUpdateCallback(Function(String, int) callback) => _skinUpdateCallbacks.add(callback);
  void setPresenceSyncCallback(Function(List<String>) callback) => _presenceSyncCallbacks.add(callback);
  void setCoinCollectedCallback(Function(String) callback) => _coinCollectedCallbacks.add(callback);
  void setLevelResetCallback(Function() callback) => _levelResetCallbacks.add(callback);
  void setPlayerAtFlagCallback(Function(String) callback) => _playerAtFlagCallbacks.add(callback);
  void setStartGameCallback(Function(String) callback) => _startGameCallbacks.add(callback);


  // 1. Đăng nhập Ẩn danh
  Future<void> signInAnonymously() async {
    try {
      if (_client.auth.currentUser != null) return;
      await _client.auth.signInAnonymously();
    } catch (e) {
      print('Supabase Auth Error: $e');
    }
  }

  // 2. Upload ảnh Profile
  Future<String?> uploadProfilePicture(String userId, File imageFile) async {
    try {
      final fileName = 'avatars/$userId.png';
      await _client.storage.from('game_assets').upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );
      return _client.storage.from('game_assets').getPublicUrl(fileName);
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  // 3. Tham gia phòng với PRESENCE
  Future<bool> joinRoom(String roomId, Function(Map<String, dynamic>) onMoveData) async {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) return false;

    if (_roomChannel != null) {
      await _client.removeChannel(_roomChannel!);
    }

    final completer = Completer<bool>();

    _roomChannel = _client.channel(
      'room_$cleanRoomId',
      opts: const RealtimeChannelConfig(self: true),
    );

    _roomChannel!
        // Broadcast events
        .onBroadcast(event: 'move', callback: (payload) {
             _handleMovePayload(payload, onMoveData);
        })
        .onBroadcast(event: 'skin', callback: (payload) {
          final data = _extractPayload(payload);
          if (data == null || data['id'] == null) return;
          if (data['id'] != currentUserId) {
             for (final cb in _skinUpdateCallbacks) cb(data['id'], data['idx'] ?? 0);
          }
        })
        .onBroadcast(event: 'start_game', callback: (payload) {
           final data = _extractPayload(payload);
           print("START GAME received: $data");
           if (data != null && data['level_id'] != null) {
             for (final cb in _startGameCallbacks) cb(data['level_id']);
           }
        })
        .onBroadcast(event: 'reset', callback: (payload) {
           final data = _extractPayload(payload);
           if (data != null && data['id'] != currentUserId) {
              for (final cb in _levelResetCallbacks) cb();
           }
        })
        .onBroadcast(event: 'coin', callback: (payload) {
           final data = _extractPayload(payload);
           if (data != null && data['id'] != currentUserId) {
             for (final cb in _coinCollectedCallbacks) cb(data['coin_id']);
           }
        })
        .onBroadcast(event: 'flag', callback: (payload) {
           final data = _extractPayload(payload);
           if (data != null && data['id'] != currentUserId) {
             for (final cb in _playerAtFlagCallbacks) cb(data['id']);
           }
        })
        // PRESENCE
        .onPresenceSync((payload) {
          print('Presence Sync: $payload');
          _handlePresenceSync();
        })
        .subscribe((status, [error]) {
           print('Channel Status: $status, Error: $error');
           if (status == RealtimeSubscribeStatus.subscribed) {
             // Track user presence explicitly
             _roomChannel!.track({'user_id': currentUserId});
             
             if (!completer.isCompleted) completer.complete(true);
           } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.timedOut) {
             if (!completer.isCompleted) completer.complete(false);
           }
        });
        
    // Timeout safety
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
  }
  
  void _handleMovePayload(dynamic payload, Function(Map<String, dynamic>) onMoveData) {
      final data = _extractPayload(payload);
      if (data == null || data['id'] == null) return;
      if (data['id'] != currentUserId) {
        onMoveData(data); // Callback passed directly to joinRoom (usually from RoomProvider)
        // AND notify all subscribed listeners (e.g. PicoGame)
        for (final cb in _gameMoveCallbacks) cb(data);
      }
  }

  // Helper: Extract data from payload (handles both nested and direct structures)
  Map<String, dynamic>? _extractPayload(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      // Could be nested: { payload: {...} } or direct: {...data...}
      if (payload.containsKey('payload') && payload['payload'] is Map) {
        return payload['payload'] as Map<String, dynamic>;
      } else {
        return payload;
      }
    }
    return null;
  }

  void _handlePresenceSync() {
    if (_roomChannel == null) return;
    
    final presenceState = _roomChannel!.presenceState();
    final List<String> playerIds = [];
    
    for (final singlePresence in presenceState) {
      for (final presence in singlePresence.presences) {
        final userId = presence.payload['user_id'] as String?;
        if (userId != null && !playerIds.contains(userId)) {
          playerIds.add(userId);
        }
      }
    }
    
    print('Presence sync: ${playerIds.length} players online: $playerIds');
    
    // Create copy to iterate safely
    final listeners = List.from(_presenceSyncCallbacks);
    for (final cb in listeners) {
       try {
         cb(playerIds);
       } catch (e) {
         print("Error in Presence Callback: $e");
       }
    }
  }

  // 4. Broadcast vị trí
  Future<void> broadcastPosition({
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
    required bool isFlipped,
  }) async {
    if (_roomChannel == null || currentUserId == null) return;

    await _roomChannel!.sendBroadcastMessage(
      event: 'move',
      payload: {
        'id': currentUserId,
        'x': x,
        'y': y,
        'vx': velocityX,
        'vy': velocityY,
        'f': isFlipped,
      },
    );
  }

  // 5. Broadcast coin collected
  Future<void> broadcastCoinCollected(String coinId) async {
    if (_roomChannel == null || currentUserId == null) return;
    await _roomChannel!.sendBroadcastMessage(
      event: 'coin', // Changed from coin_collected
      payload: {'id': currentUserId, 'coin_id': coinId},
    );
  }

  // 6. Broadcast level reset (player died)
  Future<void> broadcastLevelReset() async {
    if (_roomChannel == null || currentUserId == null) return;
    await _roomChannel!.sendBroadcastMessage(
      event: 'reset', // Changed from level_reset
      payload: {'id': currentUserId},
    );
  }

  // 7. Broadcast player at flag
  Future<void> broadcastPlayerAtFlag() async {
    if (_roomChannel == null || currentUserId == null) return;
    await _roomChannel!.sendBroadcastMessage(
      event: 'flag', // Changed from player_at_flag
      payload: {'id': currentUserId},
    );
  }

  // 8. Broadcast game start (all players navigate together)
  Future<void> broadcastStartGame(String levelId) async {
    if (_roomChannel == null || currentUserId == null) return;
    
    // RETRY LOGIC: Send 3 times to ensure delivery
    for (int i = 0; i < 3; i++) {
        print("Broadcasting Start Game: Attempt ${i+1}");
        await _roomChannel!.sendBroadcastMessage(
          event: 'start_game',
          payload: {'id': currentUserId, 'level_id': levelId},
        );
        await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void leaveRoom() {
    if (_roomChannel != null) {
      _roomChannel!.untrack();
      _client.removeChannel(_roomChannel!);
      _roomChannel = null;
    }
    clearGameCallbacks();
    _skinUpdateCallbacks.clear();
    _presenceSyncCallbacks.clear();
    _startGameCallbacks.clear();
  }
  
  // Clear callbacks related to specific game instance (called when level changes)
  void clearGameCallbacks() {
    _gameMoveCallbacks.clear();
    _coinCollectedCallbacks.clear();
    _levelResetCallbacks.clear();
    _playerAtFlagCallbacks.clear();
  }

  Future<void> broadcastSkin(int skinIndex) async {
    if (_roomChannel == null || currentUserId == null) return;
    await _roomChannel!.sendBroadcastMessage(
      event: 'skin',
      payload: {'id': currentUserId, 'idx': skinIndex},
    );
  }
}