import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../game/pico_game.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/pixel_card.dart';

class PauseMenu extends StatelessWidget {
  final dynamic game;

  const PauseMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PixelCard(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
              'PAUSED',
              style: AppTheme.pixelFont.copyWith(
                color: AppTheme.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            
            // Resume
            _buildMenuButton(
              context, 
              label: 'RESUME', 
              icon: Icons.play_arrow,
              onPressed: () {
                game.overlays.remove('PauseMenu');
                game.resumeEngine();
              },
            ),
            const SizedBox(height: 16),

            // Restart
            _buildMenuButton(
              context, 
              label: 'RESTART', 
              icon: Icons.refresh,
              onPressed: () {
                game.overlays.remove('PauseMenu');
                game.resumeEngine(); // Cần resume trước khi dispose để tránh lỗi
                context.pushReplacement('/play/${game.levelId}');
              },
            ),
            const SizedBox(height: 16),

            // Exit
            _buildMenuButton(
              context, 
              label: 'EXIT', 
              icon: Icons.exit_to_app,
              color: Colors.redAccent,
              onPressed: () {
                game.overlays.remove('PauseMenu');
                game.resumeEngine();
                context.go('/levels');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {
    required String label, 
    required IconData icon, 
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: AppTheme.pixelButtonStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(Colors.black.withOpacity(0.5)),
          overlayColor: WidgetStatePropertyAll(color.withOpacity(0.2)),
        ),
        icon: Icon(icon, color: color),
        label: Text(
          label,
          style: AppTheme.pixelFont.copyWith(color: color, fontSize: 18),
        ),
      ),
    );
  }
}
