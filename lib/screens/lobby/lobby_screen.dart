import 'package:flame/game.dart';
import 'package:flame/widgets.dart'; // Import SpriteWidget
import 'package:flame/components.dart' show Sprite; // Import Sprite
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../game/pico_game.dart';
import '../../providers/room_provider.dart';
import '../../core/utils/pixel_ui.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  bool isInRoom = false;
  bool _isJoining = false;
  String? _errorMessage;
  bool _callbackSetup = false;
  
  // Cache game instances to prevent recreation on rebuild
  PicoGame? _lobbyGame;
  String? _lastRoomId;

  PicoGame _getOrCreateGame(dynamic roomState, dynamic roomNotifier) {
    final roomId = roomState.roomId as String?;
    
    // Create new game only if:
    // 1. No game exists yet, OR
    // 2. Room changed (joined/left room)
    if (_lobbyGame == null || _lastRoomId != roomId) {
      _lastRoomId = roomId;
      _lobbyGame = PicoGame(
        levelId: 'lobby',
        players: roomState.players,
        currentUserId: roomState.currentUserId,
        supabaseService: roomId != null ? roomNotifier.supabaseService : null,
      );
    }
    return _lobbyGame!;
  }
  
  void _setupStartGameCallback() {
    if (_callbackSetup) return;
    _callbackSetup = true;
    
    ref.read(roomProvider.notifier).setStartGameCallback((levelId) {
      // All players receive this - navigate to game
      // Note: Host ignores this due to self-broadcast filter in Service
      if (mounted) {
        if (levelId.startsWith('map')) {
           print("Lobby Client received Start Game: $levelId");
           context.go('/play/$levelId'); // Use go to dispose Lobby
        } else {
           // Fallback/Error handling
           print("Unknown level ID received: $levelId");
        }
      }
    });
  }

  @override
  void dispose() {
    _lobbyGame = null; // Clear reference
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final roomNotifier = ref.read(roomProvider.notifier);
    isInRoom = roomState.roomId != null;
    
    // Setup callback when in room
    if (isInRoom) {
      _setupStartGameCallback();
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. GAME - Cached instance, only created once
          Positioned.fill(
            child: Opacity(
              opacity: isInRoom ? 1.0 : 0.6,
              child: GameWidget(
                game: _getOrCreateGame(roomState, roomNotifier),
              ),
            ),
          ),

          // 2. UI OVERLAY
          SafeArea(
            child: isInRoom 
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildLobbyHUD(context, roomState),
                )
              : Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildJoinDialog(context),
                    ),
                  ),
                ),
          ),
          
          // 3. BACK BUTTON (Chỉ hiển thị khi chưa vào phòng)
          if (!isInRoom)
            Positioned(
              top: 20,
              left: 20,
              child: PixelUI.iconButton(
                icon: Icons.arrow_back,
                onPressed: () => context.go('/'),
              ),
            ),
        ],
      ),
    );
  }

  // --- MÀN HÌNH NHẬP ID / TẠO PHÒNG ---
  Widget _buildJoinDialog(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tiêu đề
        Text(
          "MULTIPLAYER",
          style: PixelUI.font(size: 60, color: Colors.white).copyWith(
            shadows: [const BoxShadow(color: Colors.black, offset: Offset(4, 4))],
          ),
        ),
        const SizedBox(height: 40),

        // Hộp thoại chính
        Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2d1b2e), // Màu tím than đậm
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                offset: const Offset(8, 8),
              )
            ],
          ),
          child: Column(
            children: [
              // Nút Tạo Phòng
              PixelUI.button(
                text: "CREATE ROOM",
                color: const Color(0xFF88C070), // Xanh lá
                width: double.infinity,
                onPressed: () => ref.read(roomProvider.notifier).createRoom("Player"),
              ),
              
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(child: Divider(color: Colors.white, thickness: 2)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text("OR", style: PixelUI.font(size: 20, color: Colors.grey)),
                ),
                const Expanded(child: Divider(color: Colors.white, thickness: 2)),
              ]),
              const SizedBox(height: 24),

              // Ô Nhập ID
              PixelUI.textField(
                controller: _roomIdController,
                hint: "ENTER ROOM ID",
              ),
              const SizedBox(height: 16),
              
              // Thông báo lỗi (nếu có)
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: PixelUI.font(size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Nút Join
              PixelUI.button(
                text: _isJoining ? "JOINING..." : "JOIN ROOM",
                color: _isJoining ? Colors.grey : const Color(0xFFe0c070), // Vàng
                width: double.infinity,
                onPressed: _isJoining ? () {} : () => _joinRoom(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Hàm xử lý Join Room với kiểm tra timeout
  Future<void> _joinRoom() async {
    final roomId = _roomIdController.text.trim();
    
    // Validate input
    if (roomId.isEmpty) {
      setState(() {
        _errorMessage = "Please enter a Room ID!";
      });
      return;
    }
    
    if (roomId.length < 4) {
      setState(() {
        _errorMessage = "Room ID must be at least 4 characters!";
      });
      return;
    }

    // Reset error và bắt đầu loading
    setState(() {
      _errorMessage = "Connecting to server..."; // Show status
      _isJoining = true;
    });

    // Thực hiện join và chờ kết quả kết nối (10s timeout from service)
    final connected = await ref.read(roomProvider.notifier).joinRoom(roomId, "Player");

    if (!mounted) return;

    if (!connected) {
      setState(() {
        _isJoining = false;
        _errorMessage = "Connection Failed! Check internet or Room ID.";
      });
      return;
    }

    // Đã kết nối thành công, kiểm tra Presence
    await Future.delayed(const Duration(seconds: 2)); // Chờ presence sync 1 xíu

    final roomState = ref.read(roomProvider);
    
    // Nếu chỉ có 1 người (chính mình) -> cảnh báo
    if (roomState.players.length <= 1 && !roomState.isHost) {
      setState(() {
        _isJoining = false;
        // _errorMessage = "Joined! Waiting for players..."; // Optional
      });
    } else {
      // Join thành công
      setState(() {
        _isJoining = false;
      });
    }
  }

  Widget _buildLobbyHUD(BuildContext context, dynamic roomState) {
    return Stack(
      children: [
        // TOP BAR: Room ID + Settings
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Room ID Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("ROOM: ", style: PixelUI.font(size: 16, color: Colors.grey)),
                    Text(
                      roomState.roomId ?? "???",
                      style: PixelUI.font(size: 24, color: Colors.black),
                    ),
                  ],
                ),
              ),
              
              // Player Count + Settings Button
              Row(
                children: [
                  // Player count indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      "👥 ${roomState.players.length}/4",
                      style: PixelUI.font(size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Settings Button
                  PixelUI.iconButton(
                    icon: Icons.settings,
                    onPressed: () => _showSettingsDialog(context, roomState),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // BOTTOM BAR: Leave + Start
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Leave Button
              PixelUI.button(
                text: "LEAVE",
                color: const Color(0xFFe080a0),
                width: 120,
                onPressed: () {
                  ref.read(roomProvider.notifier).leaveRoom();
                },
              ),
              
              const SizedBox(width: 20),

              // Start Button (Host only)
              if (roomState.isHost)
                PixelUI.button(
                  text: "START",
                  color: const Color(0xFF88C070),
                  width: 140,
                  onPressed: () {
                    // Navigate Host to Level Selection (Do not broadcast yet)
                    // Broadcast will happen when Host selects a specific level
                    context.go('/levels');
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    "WAITING...",
                    style: PixelUI.font(size: 20, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Settings Dialog với Character Selector
  void _showSettingsDialog(BuildContext context, dynamic roomState) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2d1b2e),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.white, width: 4),
          borderRadius: BorderRadius.circular(0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("SETTINGS", style: PixelUI.font(size: 32, color: Colors.white)),
              const SizedBox(height: 20),
              
              // Player List
              Text("PLAYERS IN ROOM", style: PixelUI.font(size: 18, color: Colors.grey)),
              const SizedBox(height: 10),
              ...List.generate(roomState.players.length, (index) {
                final playerId = roomState.players[index];
                final isMe = playerId == roomState.currentUserId;
                final skinIdx = roomState.playerSkins[playerId] ?? 0;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(color: isMe ? Colors.white : Colors.grey, width: 2),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32, height: 32,
                        child: _getSpriteWidget(skinIdx),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "P${index + 1}${isMe ? " (YOU)" : ""}",
                        style: PixelUI.font(size: 20, color: isMe ? Colors.white : Colors.grey),
                      ),
                    ],
                  ),
                );
              }),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white),
              const SizedBox(height: 10),
              
              // Character Selector
              Text("CHOOSE CHARACTER", style: PixelUI.font(size: 18, color: Colors.grey)),
              const SizedBox(height: 10),
              _buildCharacterSelector(
                roomState.currentUserId ?? '',
                roomState.playerSkins[roomState.currentUserId] ?? 0,
              ),
              
              const SizedBox(height: 20),
              
              // Close Button
              PixelUI.button(
                text: "CLOSE",
                color: Colors.grey,
                width: 120,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Widget chọn nhân vật
  Widget _buildCharacterSelector(String userId, int currentSkinIndex) {
    // Giả sử có 4 nhân vật
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
         color: Colors.black.withOpacity(0.5),
         borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (index) {
          final isSelected = currentSkinIndex == index;
          return GestureDetector(
            onTap: () {
               ref.read(roomProvider.notifier).updateSkin(index);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border.all(color: isSelected ? Colors.black : Colors.white, width: 2),
              ),
              width: 50,
              height: 50,
              child: _getSpriteWidget(index),
            ),
          );
        }),
      ),
    );
  }
  
  // Custom Player Slot hiển thị Sprite
  Widget _buildPlayerSlotWithSprite({
    required int index,
    required bool isJoined,
    required String name,
    required bool isMe,
    required int skinIndex,
  }) {
     // Màu theo index: Xanh lá, Xanh dương, Hồng, Vàng
    final colors = [
      const Color(0xFF88C070), // Green
      const Color(0xFF88a0C0), // Blue
      const Color(0xFFe080a0), // Pink
      const Color(0xFFe0c070), // Yellow
    ];
    
    final color = colors[index % colors.length];

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 140, // Cao hơn chút để chứa Sprite
        decoration: BoxDecoration(
          color: isJoined ? color : Colors.black.withOpacity(0.5),
          border: Border.all(
            color: isMe ? Colors.white : Colors.black, 
            width: isMe ? 4 : 2
          ),
          boxShadow: isMe ? [const BoxShadow(color: Colors.white, blurRadius: 10)] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sprite Placeholder
            Container(
              width: 60, 
              height: 60, 
              alignment: Alignment.center,
              child: isJoined 
                ? Transform.scale(scale: 2.0, child: _getSpriteWidget(skinIndex))
                : const Icon(Icons.add, color: Colors.white54, size: 40),
            ),
            const SizedBox(height: 8),
            Text(
              isJoined ? name : "EMPTY",
              style: PixelUI.font(size: 24, color: isJoined ? Colors.black : Colors.white54),
            ),
            if (isMe)
              Text("(YOU)", style: PixelUI.font(size: 16, color: Colors.black)),
          ],
        ),
      ),
    );
  }
  
  // Helper lấy Sprite từ Cache
  Widget _getSpriteWidget(int skinIndex) {
     try {
       final image = Flame.images.fromCache('tilemap-characters_packed.png');
       // Tính toán tọa độ cắt (24x24 px, cách nhau 24px)
       final double spriteX = (skinIndex % 9) * 24.0; // Giả sử hàng ngang có nhiều con
       final sprite = Sprite(
         image,
         srcPosition: Vector2(spriteX, 0),
         srcSize: Vector2(24, 24),
       );
       
       return SpriteWidget(sprite: sprite);
     } catch (e) {
       return const Icon(Icons.error);
     }
  }
}
