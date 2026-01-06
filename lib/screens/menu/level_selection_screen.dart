import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import để dùng AssetManifest
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Add Provider
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // Import json decode
import '../../providers/room_provider.dart'; // Import RoomProvider

class LevelSelectionScreen extends ConsumerStatefulWidget {
  const LevelSelectionScreen({super.key});

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
  }

  Future<void> _loadLevels() async {
    try {
      // Dùng API chuẩn để lấy danh sách assets (hoạt động tốt trên cả Web & Mobile)
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      
      // Lọc các file .tmx trong assets/tiles/
      final levelFiles = manifest.listAssets()
          .where((String key) => key.contains('assets/tiles/map') && key.endsWith('.tmx'))
          .toList();

      // Parse ra số level để sắp xếp
      // Ví dụ: assets/tiles/map1.tmx -> 1
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
    // Regex lấy số từ chuỗi mapX.tmx
    final RegExp regex = RegExp(r'map(\d+)\.tmx');
    final match = regex.firstMatch(path);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 9999; // Nếu không đúng định dạng thì đẩy xuống cuối
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      body: Stack(
        children: [
          // Nút Back
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              onPressed: () => context.go('/'),
            ),
          ),
          
          Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  'SELECT LEVEL',
                  style: TextStyle(
                    fontFamily: GoogleFonts.vt323().fontFamily,
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total Maps: ${levels.length}', // Hiển thị tổng số map
                  style: TextStyle(
                    fontFamily: GoogleFonts.vt323().fontFamily,
                    fontSize: 24,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Grid View hiển thị tất cả các màn chơi
                Expanded(
                  child: isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 100, // Kích thước tối đa mỗi ô
                            childAspectRatio: 1,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: levels.length,
                          itemBuilder: (context, index) {
                            final path = levels[index];
                            final levelNum = _extractLevelNumber(path);
                            final mapId = 'map$levelNum';

                            return _buildLevelButton(context, '$levelNum', mapId);
                          },
                        ),
                      ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, String label, String mapId) {
    return GestureDetector(
      onTap: () {
         final roomState = ref.read(roomProvider);
         
         // Nếu đang trong phòng (Host), Broadcast start_game
         if (roomState.roomId != null && roomState.isHost) {
           print("Broadcasting Start Game: $mapId");
           ref.read(roomProvider.notifier).startGame(mapId);
           // Host cũng tự navigate luôn
           context.go('/play/$mapId');
         } else {
           // Chơi đơn (Offline logic)
           context.go('/play/$mapId');
         }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF7ed957), // Màu xanh Pixel
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
