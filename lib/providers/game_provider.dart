import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'game_provider.g.dart';

@riverpod
class GameNotifier extends _$GameNotifier {
  @override
  int build() => 0; // State ban đầu là 0 (số xu)

  void addCoin() {
    state++;
  }

  void syncScore(int score) {
    state = score;
  }

  void reset() {
    state = 0;
  }
}
