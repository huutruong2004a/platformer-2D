import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flame/game.dart';

import '../../screens/menu/menu_screen.dart';
import '../../screens/menu/level_selection_screen.dart'; 
import '../../screens/game/game_screen.dart';
import '../../screens/lobby/lobby_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MenuScreen(),
      ),
      GoRoute(
        path: '/lobby',
        builder: (context, state) => const LobbyScreen(),
      ),
      // Route mới: Màn hình chọn Level
      GoRoute(
        path: '/levels',
        builder: (context, state) => const LevelSelectionScreen(),
      ),
      // Route Game: Thêm tham số :levelId
      GoRoute(
        path: '/play/:levelId', 
        builder: (context, state) {
          final levelId = state.pathParameters['levelId'] ?? 'map1';
          return GameScreen(levelId: levelId);
        },
      ),
    ],
  );
}