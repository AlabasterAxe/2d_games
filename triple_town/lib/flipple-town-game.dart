import 'dart:async';

import 'package:flame/components.dart' show Anchor, Vector2;
import 'package:flame/experimental.dart'
    show CameraComponent, HasTappableComponents;
import 'package:flame/game.dart' show FlameGame;
import 'package:triple_town/world/board.dart';

class FlippleTownGame extends FlameGame with HasTappableComponents {
  final worldState = WorldState();
  @override
  FutureOr<void> onLoad() async {
    final world = getWorld(worldState);
    add(world);
    final camera = CameraComponent(world: world)
      ..viewfinder.visibleGameSize = Vector2(BOARD_SIZE * 1.15, BOARD_SIZE * 2)
      ..viewfinder.position = Vector2(0, 0)
      ..viewfinder.anchor = Anchor.center;
    add(camera);
  }
}
