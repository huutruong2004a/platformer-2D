import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added Riverpod
import 'package:go_router/go_router.dart';
import '../../game/pico_game.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/pixel_card.dart';
import '../../providers/room_provider.dart'; // Import RoomProvider

class LevelCompleteMenu extends ConsumerWidget { // Changed to ConsumerWidget
  final dynamic game; // Support both PicoGame and PicoGameSingle
  final bool isHost; // Passed from GameScreen

  const LevelCompleteMenu({
    super.key, 
    required this.game,
    this.isHost = false, // Default false for safety
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Added WidgetRef
    // Tính số sao
    int stars = 1;
    if (game.scoreNotifier.value >= game.totalCoinsInLevel) {
      stars = 3;
    } else if (game.scoreNotifier.value >= game.totalCoinsInLevel / 2) {
      stars = 2;
    }

    return Center(
      child: PixelCard(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
              'LEVEL COMPLETE!',
              style: AppTheme.pixelFont.copyWith(
                color: AppTheme.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Hiển thị sao
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Icon(
                  index < stars ? Icons.star : Icons.star_border,
                  color: Colors.yellow,
                  size: 48,
                );
              }),
            ),
            const SizedBox(height: 10),
            Text(
              'Coins: ${game.scoreNotifier.value} / ${game.totalCoinsInLevel}',
              style: AppTheme.pixelFont.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 30),
            
            // HOST CONTROLS
            if (isHost)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Nút Chơi Lại (Broadcast Start Game with SAME ID)
                  ElevatedButton(
                    onPressed: () {
                      game.overlays.remove('LevelComplete');
                      _broadcastNextLevel(context, ref, sameLevel: true); // Pass ref
                    },
                    style: AppTheme.pixelButtonStyle,
                    child: const Icon(Icons.refresh, size: 24),
                  ),
                  // Nút Màn Tiếp Theo
                  ElevatedButton(
                    onPressed: () {
                      game.overlays.remove('LevelComplete');
                      _broadcastNextLevel(context, ref); // Pass ref
                    },
                    style: AppTheme.pixelButtonStyle.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(AppTheme.primary),
                      foregroundColor: const WidgetStatePropertyAll(Colors.black),
                    ),
                    child: const Icon(Icons.arrow_forward, size: 24),
                  ),
                ],
              )
            else
              // CLIENT VIEW
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  border: Border.all(color: Colors.white),
                ),
                child: Text(
                  "WAITING FOR HOST...",
                  style: AppTheme.pixelFont.copyWith(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _broadcastNextLevel(BuildContext context, WidgetRef ref, {bool sameLevel = false}) {
    // Parse level hiện tại: "map1" -> 1
    final currentLevelNum = int.tryParse(game.levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final nextLevelNum = sameLevel ? currentLevelNum : currentLevelNum + 1;
    final nextLevelId = 'map$nextLevelNum';
    
    // Check Real Multiplayer Status via Provider
    final roomId = ref.read(roomProvider).roomId;
    final isMultiplayer = roomId != null;

    // 2. Logic điều hướng
    if (isMultiplayer && game is PicoGame && (game as PicoGame).supabaseService != null) {
       // --- MULTIPLAYER ---
       if (nextLevelNum > 8 && !sameLevel) {
          (game as PicoGame).supabaseService?.broadcastStartGame('lobby');
       } else {
          print("Host Broadcasting Start Game: $nextLevelId");
          (game as PicoGame).supabaseService?.broadcastStartGame(nextLevelId);
       }
    } else {
       // --- SINGLE PLAYER (OFFLINE) ---
       print("Single Player Local Navigation to: $nextLevelId");
       if (nextLevelNum > 8 && !sameLevel) {
          context.go('/levels'); // Go back to level selection
       } else {
          context.pushReplacement('/play/$nextLevelId');
       }
    }
  }
}
