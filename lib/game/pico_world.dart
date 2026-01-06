import 'package:flame_forge2d/flame_forge2d.dart';
import 'components/level/level_loader.dart';

class PicoWorld extends Forge2DWorld {
  // Khai báo biến
  final String currentLevelId;

  // Constructor nhận tham số currentLevelId
  PicoWorld({required this.currentLevelId});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Truyền ID và world instance vào LevelLoader
    add(LevelLoader(levelName: currentLevelId, worldRef: this));
  }
}