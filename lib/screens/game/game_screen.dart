import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../game/pico_game.dart';
import '../../game/pico_game_single.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import 'game_hud.dart';
import 'level_complete_menu.dart';
import 'pause_menu.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String levelId;

  const GameScreen({super.key, required this.levelId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  // Use generic FlameGame but we know it's either PicoGame or PicoGameSingle
  FlameGame? _game;
  DateTime? _lastStartGameTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) {
      _initGame();
    }
  }

  @override
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levelId != widget.levelId) {
      // Level changed, force re-init
      _removeListeners();
      _game = null;
      _initGame();
    }
  }

  void _initGame() {
    final roomState = ref.read(roomProvider);
    final roomNotifier = ref.read(roomProvider.notifier);
    
    if (roomState.roomId != null) {
      // === MULTIPLAYER ===
      final multiGame = PicoGame(
        levelId: widget.levelId,
        players: roomState.players,
        currentUserId: roomState.currentUserId,
        supabaseService: roomNotifier.supabaseService,
      );
      
      multiGame.scoreNotifier.addListener(_onScoreChanged);
      _game = multiGame;
      print("Initialized MULTIPLAYER Game: ${widget.levelId}");
    } else {
      // === SINGLE PLAYER ===
      final singleGame = PicoGameSingle(
        levelId: widget.levelId,
      );
      
      singleGame.scoreNotifier.addListener(_onScoreChanged);
      _game = singleGame;
      print("Initialized SINGLE PLAYER Game: ${widget.levelId}");
    }
    
    // Listen for Start Game (Next Level)
    _setupGameListeners();
    
    setState(() {}); // Trigger rebuild
  }

  void _onScoreChanged() {
    if (_game is PicoGame) {
      ref.read(gameProvider.notifier).syncScore((_game as PicoGame).scoreNotifier.value);
    } else if (_game is PicoGameSingle) {
      ref.read(gameProvider.notifier).syncScore((_game as PicoGameSingle).scoreNotifier.value);
    }
  }
  
  void _removeListeners() {
    if (_game is PicoGame) {
      (_game as PicoGame).scoreNotifier.removeListener(_onScoreChanged);
    } else if (_game is PicoGameSingle) {
      (_game as PicoGameSingle).scoreNotifier.removeListener(_onScoreChanged);
    }
  }

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }
  
  void _setupGameListeners() {
    final roomNotifier = ref.read(roomProvider.notifier);
    // Listen for "start_game" (Next Level / Restart) from Host
    roomNotifier.setStartGameCallback((levelId) {
      if (!mounted) return;
      
      // Debounce: Ignore duplicate calls within 2 seconds
      final now = DateTime.now();
      if (_lastStartGameTime != null && now.difference(_lastStartGameTime!) < const Duration(seconds: 2)) {
         print("Ignored duplicate start_game: $levelId");
         return;
      }
      _lastStartGameTime = now;
      
      print("GameScreen received start_game: $levelId");
      if (levelId.startsWith('map')) {
         context.pushReplacement('/play/$levelId');
      } else {
         context.go('/levels');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final roomState = ref.read(roomProvider);
    final isHost = (roomState.roomId == null) || roomState.isHost;
    
    return Scaffold(
      body: GameWidget(
        game: _game!,
        overlayBuilderMap: {
          'HUD': (context, game) {
             if (game is PicoGame) return GameHud(game: game);
             if (game is PicoGameSingle) return GameHud(game: game); // HUD needs update too?
             return const SizedBox();
          },
          'LevelComplete': (context, game) {
             return LevelCompleteMenu(
               game: game, // Pass dynamic or interface
               isHost: isHost
            );
          },
          'PauseMenu': (context, game) {
             return PauseMenu(game: game); // PauseMenu needs update too?
          },
        },
        initialActiveOverlays: const ['HUD'],
      ),
    );
  }
}