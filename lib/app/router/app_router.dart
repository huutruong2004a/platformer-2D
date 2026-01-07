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
      // Route: Level Selection with optional roomId
      GoRoute(
        path: '/levels',
        builder: (context, state) {
          final roomId = state.uri.queryParameters['roomId'];
          print("AppRouter: /levels route, roomId from URL: $roomId");
          return LevelSelectionScreen(roomIdFromUrl: roomId);
        },
      ),
      // Route Game: Thêm tham số :levelId và optional query params
      GoRoute(
        path: '/play/:levelId', 
        builder: (context, state) {
          final levelId = state.pathParameters['levelId'] ?? 'map1';
          // Get optional query parameters for multiplayer
          final roomId = state.uri.queryParameters['roomId'];
          final isMultiplayer = roomId != null && roomId.isNotEmpty;
          
          print("AppRouter: Creating GameScreen with levelId=$levelId, roomId=$roomId, isMultiplayer=$isMultiplayer");
          
          return GameScreen(
            levelId: levelId, 
            roomIdFromUrl: roomId,
          );
        },
      ),
    ],
  );
}