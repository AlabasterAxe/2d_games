import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart' show Anchor, Vector2;
import 'package:flame/experimental.dart'
    show CameraComponent, HasTappableComponents, World;
import 'package:flame/game.dart' show FlameGame;
import 'package:triple_town/world/board.dart';

class FlippleTownGame extends FlameGame with HasTappableComponents {
  var worldState = WorldState();
  CameraComponent? cameraComponent;
  var time = 0.0;
  @override
  FutureOr<void> onLoad() async {
    late World world;
    world = FlippleWorld(WorldState());
    add(world);
    cameraComponent = CameraComponent(world: world)
      ..viewfinder.visibleGameSize = Vector2(BOARD_SIZE * 1.15, BOARD_SIZE * 2)
      ..viewfinder.position = Vector2(0, 0)
      ..viewfinder.anchor = Anchor.center;
    add(cameraComponent!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;
    cameraComponent!.viewfinder.position = Vector2(
      (2 * sin(time)),
      (2 * cos(time)),
    );
    cameraComponent!.viewfinder.angle = (pi / 720) * sin(time);
  }
}
