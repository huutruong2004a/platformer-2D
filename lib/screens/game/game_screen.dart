import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../game/pico_game.dart';
import '../../game/pico_game_single.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../data/supabase_service.dart';
import 'game_hud.dart';
import 'level_complete_menu.dart';
import 'pause_menu.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String levelId;
  final String? roomIdFromUrl; // Optional: passed from URL for multiplayer

  const GameScreen({
    super.key, 
    required this.levelId,
    this.roomIdFromUrl,
  });

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
    final supabaseService = roomNotifier.supabaseService;
    
    // DEBUG: Log all state
    print("GameScreen _initGame:");
    print("  - widget.roomIdFromUrl: ${widget.roomIdFromUrl}");
    print("  - roomState.roomId: ${roomState.roomId}");
    print("  - roomState.isHost: ${roomState.isHost}");
    print("  - roomState.players: ${roomState.players.length}");
    
    // Determine if this is a multiplayer game:
    // 1. Check provider state first
    // 2. Fallback to URL parameter if provider state is lost
    final isMultiplayer = roomState.roomId != null || widget.roomIdFromUrl != null;
    
    if (isMultiplayer) {
      // === MULTIPLAYER ===
      // CRITICAL FIX: Use SupabaseService singleton as fallback when RoomProvider state is lost
      // This happens when Host navigates from LevelSelectionScreen (state not preserved)
      final currentUserId = roomState.currentUserId ?? supabaseService.currentUserId;
      
      // If we have no players from state, use current user as the only known player
      // Other players will be added via Self-Healing when they send move data
      List<String> players = roomState.players.isNotEmpty 
          ? roomState.players 
          : (currentUserId != null ? [currentUserId] : []);
      
      print("Creating MULTIPLAYER Game");
      print("  - Players from state: ${roomState.players}");
      print("  - CurrentUserId (resolved): $currentUserId");
      print("  - Final players list: $players");
      
      final multiGame = PicoGame(
        levelId: widget.levelId,
        players: players,
        currentUserId: currentUserId,
        supabaseService: supabaseService,
      );
      
      multiGame.scoreNotifier.addListener(_onScoreChanged);
      _game = multiGame;
      
      // Update presence with current level for late-joiners
      supabaseService.setCurrentLevel(widget.levelId);
      
      print("Initialized MULTIPLAYER Game: ${widget.levelId}");
    } else {
      // === SINGLE PLAYER ===
      print("Creating SINGLE PLAYER Game (no roomId in state or URL)");
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

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }
  
  void _setupGameListeners() {
    // CRITICAL: Register start_game callback for CLIENTS to navigate to next level
    // When Host clicks "Next Level", clients need this callback to navigate
    final roomId = widget.roomIdFromUrl;
    if (roomId != null && _game is PicoGame) {
      print("GameScreen: Setting up start_game callback for multiplayer (roomId: $roomId)");
      SupabaseService().setStartGameCallback((levelId) {
        print("GameScreen: Received start_game for level: $levelId");
        if (mounted) {
          // Navigate to next level
          if (levelId == 'lobby') {
            context.go('/lobby');
          } else {
            context.go('/play/$levelId?roomId=$roomId');
          }
        }
      });
    } else {
      print("GameScreen: Single player mode - no start_game callback needed");
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
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    // Single player (no room) = always treated as host for navigation buttons
    final isSinglePlayer = roomState.roomId == null;
    final isHost = isSinglePlayer || roomState.isHost;
    
    if (_game == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      body: GameWidget(
        game: _game!,
        overlayBuilderMap: {
          'HUD': (context, game) => GameHud(game: game),
          'LevelComplete': (context, game) => LevelCompleteMenu(game: game, isHost: isHost),
          'PauseMenu': (context, game) => PauseMenu(game: game),
        },
        initialActiveOverlays: const ['HUD'],
      ),
    );
  }
}