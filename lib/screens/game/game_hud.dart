import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../game/pico_game.dart';
import '../../providers/game_provider.dart'; // Đảm bảo import này chính xác

// Chuyển sang ConsumerWidget
class GameHud extends ConsumerWidget {
  final dynamic game;

  const GameHud({super.key, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lắng nghe gameNotifierProvider (sinh ra từ GameNotifier)
    final currentScore = ref.watch(gameProvider); 
    
    return Stack(
      children: [
        Positioned(
          top: 20,
          left: 20,
          child: InkWell(
            onTap: () {
              game.pauseEngine();
              game.overlays.add('PauseMenu');
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 24),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: currentScore >= 3 ? Colors.greenAccent : Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/tilemap_packed.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '$currentScore / 3',
                  style: TextStyle(
                    color: currentScore >= 3 ? Colors.greenAccent : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
                if (currentScore >= 3)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
