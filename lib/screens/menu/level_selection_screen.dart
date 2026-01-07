import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../providers/room_provider.dart';

class LevelSelectionScreen extends ConsumerStatefulWidget {
  final String? roomIdFromUrl; // Room ID from URL for multiplayer

  const LevelSelectionScreen({super.key, this.roomIdFromUrl});

  @override
  ConsumerState<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends ConsumerState<LevelSelectionScreen> {
  List<String> levels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLevels();
    // Debug log
    print("LevelSelectionScreen init: roomIdFromUrl=${widget.roomIdFromUrl}");
  }

  Future<void> _loadLevels() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      
      final levelFiles = manifest.listAssets()
          .where((String key) => key.contains('assets/tiles/map') && key.endsWith('.tmx'))
          .toList();

      levelFiles.sort((a, b) {
        final int numA = _extractLevelNumber(a);
        final int numB = _extractLevelNumber(b);
        return numA.compareTo(numB);
      });

      setState(() {
        levels = levelFiles;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading levels: $e');
      setState(() => isLoading = false);
    }
  }

  int _extractLevelNumber(String path) {
    final RegExp regex = RegExp(r'map(\d+)\.tmx');
    final match = regex.firstMatch(path);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 999;
  }

  @override
  Widget build(BuildContext context) {
    // Determine if this is multiplayer based on URL param
    final isMultiplayer = widget.roomIdFromUrl != null && widget.roomIdFromUrl!.isNotEmpty;
    
    return Scaffold(
      backgroundColor: const Color(0xFF2d1b2e),
      appBar: AppBar(
        title: Text(
          isMultiplayer ? 'SELECT LEVEL (Room: ${widget.roomIdFromUrl})' : 'SELECT LEVEL',
          style: TextStyle(fontFamily: GoogleFonts.vt323().fontFamily, fontSize: 24),
        ),
        backgroundColor: const Color(0xFF2d1b2e),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (isMultiplayer) {
              context.go('/lobby');
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: levels.length,
                itemBuilder: (context, index) {
                  final levelPath = levels[index];
                  final levelNumber = _extractLevelNumber(levelPath);
                  final mapId = 'map$levelNumber';
                  return _buildLevelButton(context, 'Level $levelNumber', mapId, isMultiplayer);
                },
              ),
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, String label, String mapId, bool isMultiplayer) {
    return GestureDetector(
      onTap: () async {
         // Use roomIdFromUrl for multiplayer detection
         final roomId = widget.roomIdFromUrl;
         
         print("LevelSelection onTap: mapId=$mapId, roomIdFromUrl=$roomId, isMultiplayer=$isMultiplayer");
         
         if (isMultiplayer && roomId != null) {
           // MULTIPLAYER: Broadcast start_game and navigate
           print("Host: Broadcasting Start Game: $mapId for room $roomId");
           await ref.read(roomProvider.notifier).startGame(mapId);
           print("Host: Broadcast complete, now navigating to $mapId");
           // Give WebSocket time to propagate to all clients
           await Future.delayed(const Duration(milliseconds: 500));
           if (context.mounted) {
             context.go('/play/$mapId?roomId=$roomId');
           }
         } else {
           // SINGLE PLAYER
           print("Single Player: Navigating to $mapId");
           context.go('/play/$mapId');
         }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF7ed957),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: GoogleFonts.vt323().fontFamily,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
