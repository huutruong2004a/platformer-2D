import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/supabase_service.dart';

part 'room_provider.g.dart';

// State Class
class RoomState {
  final String? roomId;
  final List<String> players;
  final bool isHost;
  final String? currentUserId;
  final Map<String, int> playerSkins; // Map UserId -> SkinIndex

  const RoomState({
    this.roomId, 
    this.players = const [], 
    this.isHost = false, 
    this.currentUserId,
    this.playerSkins = const {},
  });

  RoomState copyWith({
    String? roomId, 
    List<String>? players, 
    bool? isHost, 
    String? currentUserId,
    Map<String, int>? playerSkins,
  }) {
    return RoomState(
      roomId: roomId ?? this.roomId,
      players: players ?? this.players,
      isHost: isHost ?? this.isHost,
      currentUserId: currentUserId ?? this.currentUserId,
      playerSkins: playerSkins ?? this.playerSkins,
    );
  }
}

@Riverpod(keepAlive: true)
class RoomNotifier extends _$RoomNotifier {
  final _supabaseService = SupabaseService();
  
  // Expose service cho Game sử dụng
  SupabaseService get supabaseService => _supabaseService;

  @override
  RoomState build() => const RoomState();

  Future<void> createRoom(String playerName) async {
    print("Creating Room...");
    await _supabaseService.signInAnonymously();
    final newRoomId = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    final userId = _supabaseService.currentUserId ?? 'Host';
    
    state = state.copyWith(
      roomId: newRoomId,
      isHost: true,
      players: [userId],
      currentUserId: userId,
    );
    print("Room Created: $newRoomId by $userId");

    _joinRealtimeChannel();
  }

  Future<bool> joinRoom(String roomId, String playerName) async {
    if (roomId.isEmpty) return false;
    await _supabaseService.signInAnonymously();
    
    state = state.copyWith(
      roomId: roomId,
      isHost: false,
      players: [_supabaseService.currentUserId ?? 'Player'],
      currentUserId: _supabaseService.currentUserId ?? 'Player',
    );

    return await _joinRealtimeChannel();
  }
  
  // Hàm chọn Skin
  void updateSkin(int index) {
    if (state.currentUserId == null) return;
    
    // Update Local State
    final newSkins = Map<String, int>.from(state.playerSkins);
    newSkins[state.currentUserId!] = index;
    state = state.copyWith(playerSkins: newSkins);
    
    // Broadcast to others
    _supabaseService.broadcastSkin(index);
  }

  Future<bool> _joinRealtimeChannel() async {
    final roomId = state.roomId;
    if (roomId == null) return false;

    // Set Default Skin for self if not set
    if (state.currentUserId != null && !state.playerSkins.containsKey(state.currentUserId)) {
       final newSkins = Map<String, int>.from(state.playerSkins);
       newSkins[state.currentUserId!] = 0; // Default Green
       state = state.copyWith(playerSkins: newSkins);
    }
    
    // Listen for Skin Updates
    _supabaseService.setSkinUpdateCallback((userId, skinIndex) {
       try {
         final newSkins = Map<String, int>.from(state.playerSkins);
         newSkins[userId] = skinIndex;
         state = state.copyWith(playerSkins: newSkins);
       } catch (e) {
         print("Error in Skin callback: $e");
       }
    });

    // PRESENCE: Listen for player list changes
    _supabaseService.setPresenceSyncCallback((playerIds) {
      try {
        print("Presence updated: $playerIds");
        state = state.copyWith(players: playerIds);
        
        // Broadcast skin của mình cho người mới vào
        if (state.currentUserId != null && state.playerSkins.containsKey(state.currentUserId)) {
          _supabaseService.broadcastSkin(state.playerSkins[state.currentUserId]!);
        }
      } catch (e) {
        print("Error in Presence callback: $e");
      }
    });


    return await _supabaseService.joinRoom(roomId, (data) {
      // Move data callback (handled by PicoGame)
    });
  }
  
  // Set callback for when start_game is received
  void setStartGameCallback(Function(String levelId) callback) {
    _supabaseService.setStartGameCallback(callback);
  }
  
  // Broadcast start game to all players
  Future<void> startGame(String levelId) async {
    await _supabaseService.broadcastStartGame(levelId);
  }

  void leaveRoom() {
    _supabaseService.leaveRoom();
    // Reset state but keep user ID if desired, or full reset
    final userId = state.currentUserId ?? 'Player';
    state = RoomState(currentUserId: userId, players: [userId]);
  }
}