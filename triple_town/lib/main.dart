import 'package:flame/game.dart' show FlameGame, GameWidget;
import 'package:flutter/widgets.dart';

void main() {
  final game = FlameGame();
  runApp(GameWidget(game: game));
}
